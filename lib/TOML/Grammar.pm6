use ForeignGrammar;
grammar TOML::Grammar;
token ws { [<[\ \t]>|'#'\N*]* }

rule TOP {
    :my %top;
    ^ \n *
    [[
    | <keyvalue>    { %top{.key} =     .value for @<keyvalue>\  [*-1].ast }
    | <table>       { %top{.key} =     .value for @<table>\     [*-1].ast  }
    | <table_array> { %top{.key}.push: .value for @<table_array>[*-1].ast }
    ] \n * ]*
    $
    { make $%top }
}

token key { <:L+:N+[_-]>+ }

rule keyvalue {
    <key> '=' <value>
    { make $<key>.Str => $<value>.ast }
}

rule table {
    '[' ~ ']' <key>+ % \. \n
    <keyvalue> *
    {
        my %table;
        %table{.key} = .value for @<keyvalue>».ast;
        make lol(|@<key>.map({.Str})) => %table;
    }
}

rule table_array {
    '[[' ~ ']]' <key>+ % \. \n
    <keyvalue> *
    {
        my %table;
        %table{.key} = .value for @<keyvalue>».ast;
        make lol(|@<key>.map({.Str})) => %table;
    }
}

grammar Value {...}

token value {
    <val=.Value::value> { make $<val>.ast }
}

grammar Value does ForeignGrammar {
    token ws { [\n|' '|\t|'#'\N*]* }
    rule value {
        [
        | <integer>
        | <float>
        | <array>
        | <bool>
        | <datetime>
        | <string>
        ]
        {
            my ($k, $v) = %().kv;
            if $*JSON_COMPAT {
                make { type => $k, value => $k eq 'datetime' ?? ~$v !! $v.ast };
            } else {
                make $v.ast;
            }
        }
    }

    token integer { <[+-]>? \d+ { make +$/ } }
    token float { <[+-]>? \d+ [\.\d+]? [<[Ee]> <integer>]? { make +$/ }}
    rule array {
        \[ ~ \] <value> *% \,
        { make my@ = @<value>».ast }
    }
    token bool {
        | true { make True }
        | false { make False }
    }

    token datetime {
        (\d**4) '-' (\d\d) '-' (\d\d)
        T
        (\d\d) ':' (\d\d) ':' (\d\d) Z
        {
            make DateTime.new: |%(
                <year month day hour minute second> Z=> map +*, @()
            )
        }
    }

    proto token string { * }
    # proto token string { {*} { make $<call-rule>.ast } }

    grammar String {
        token stopper { \' }
        token string { <chars>+ {make @<chars>.map({.ast}).join}}
        proto token chars { * }
        token chars:non-control { <-[\x00..\x1F\\]-stopper>+ {make ~$/}}
        token chars:escape { \\ }
    }

    role Escapes {
        token chars:escape {
            \\ [ <escape> || . { die "Found bad escape sequence $/" } ]
            {make $<escape>.ast}
        }
        proto token escape { * }
        token escape:sym<b> { <sym> {make "\b"}}
        token escape:sym<t> { <sym> {make "\t"}}
        token escape:sym<n> { <sym> {make "\n"}}
        token escape:sym<f> { <sym> {make "\f"}}
        token escape:sym<r> { <sym> {make "\r"}}
        token escape:backslash { \\ {make '\\'}}
        token escape:stopper { <stopper> {make ~$/}}
        token hex { <[0..9A..F]> }
        token escape:sym<u> { <sym> <hex>**4 {make chr :16[@<hex>]}}
        token escape:sym<U> { <sym> <hex>**8 {make chr :16[@<hex>]}}
    }

    role Multi {
        token chars:newline { \n+ {make ~$/}}
        token escape:newline { \n\s* {make ""}}
    }

    token string:sym<'> {
        <sym> ~ <sym> <foreign-rule: 'string', String>
        { make $<foreign-rule>.ast }
    }
    token string:sym<'''> {
        [<sym>\n?] ~ <sym> <foreign-rule: 'string', state$= String but Multi>
        { make $<foreign-rule>.ast }
    }
    token string:sym<"> {
        <sym> ~ <sym>
        <foreign-rule: 'string', state$= String but role :: does Escapes {
                token stopper { \" }
        }>
        { make $<foreign-rule>.ast }
    }
    token string:sym<"""> {
        [<sym>\n?] ~ <sym>
        <foreign-rule: 'string', state$= String but role :: does Escapes does Multi {
            token stopper { '"""' }
        }>
        { make $<foreign-rule>.ast }
    }
}

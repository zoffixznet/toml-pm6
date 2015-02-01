use ForeignGrammar;
grammar TOML::Grammar;
grammar Value {...}

token ws { [<[\ \t]>|'#'\N*]* }

role AoH {
    method at_key($key) is rw { self[*-1]{$key} }
    method assign_key($key, \assign) is rw { self[*-1]{$key} = assign }
}

rule TOP {
    :my %top;
    :my %*array_names;
    ^ \n *
    [[
    | <keyvalue> { given @<keyvalue>[*-1].ast {
        die "Name {.key.join('.')} already in use." if [||] %top{.key}:exists;
        %top{.key} = .value;
    } }
    | <table> { given @<table>[*-1].ast {
        die "Name {.key.join('.')} already in use." if [||] %top{.key}:exists;
        %top{.key} = .value;
    } }
    | <table_array> { given @<table_array>[*-1].ast {
        my $already_array = [||] %*array_names{.key};
        die "Name {.key.join('.')} already used as a table."
            if [||](%top{.key}:exists) and not $already_array;
        ([||] %top{.key}) || %top{.key} = [] but AoH;
        %top{.key,}[0].push: .value;
        %*array_names{.key} = True;
    } }
    ] \n * ]*
    [ $ || { die "Couldn't parse TOML: $/" } ]
    { make $%top }
}

token key {
    [ <[A..Za..z0..9_-]>+ | <?before \"<-["]> ><str=.Value::string> ]
    {
        make $<str> ?? $<str>.ast !! $/.Str;
    }
}

token value {
    <val=.Value::value> { make $<val>.ast }
}

rule keyvalue {
    <key> '=' <value>
    { make $<key>.ast => $<value>.ast }
}

rule table {
    '[' ~ ']' <key>+ % \. \n
    <keyvalue> *
    {
        my %table;
        %table{.key} = .value for @<keyvalue>».ast;
        make lol(|@<key>.map({.ast})) => %table;
    }
}

rule table_array {
    '[[' ~ ']]' <key>+ % \. \n
    <keyvalue> *
    {
        my %table;
        %table{.key} = .value for @<keyvalue>».ast;
        make lol(|@<key>.map({.ast})) => %table;
    }
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
                make { type => $k, value => $k (elem) <datetime bool integer float> ?? ~$v !! $v.ast };
            } else {
                make $v.ast;
            }
        }
    }

    token integer { <[+-]>? \d+ { make +$/ } }
    token float { <[+-]>? \d+ [\.\d+]? [<[Ee]> <integer>]? { make +$/ }}
    rule array {
        \[ ~ \] <value> * %% \,
        { make my@ = @<value>».ast }
    }
    token bool {
        | true { make True }
        | false { make False }
    }

    token datetime {
        (\d**4) '-' (\d\d) '-' (\d\d)
        <[Tt]>
        (\d\d) ':' (\d\d) ':' (\d\d ['.' \d+]?)
        [
        | <[Zz]>
        | (<[+-]> \d\d) ':' (\d\d)
        ]
        {
            make DateTime.new: |%(
                <year month day hour minute second> Z=> map +*, @()
                :timezone( $6 ?? (($6*60 + $7) * 60).Int !! 0 )
            )
        }
    }

    proto token string { * }
    # proto token string { {*} { make $<call-rule>.ast } }

    grammar String {
        token stopper { \' }
        token string { <chars>* {make @<chars>.map({.ast}).join}}
        proto token chars { * }
        token chars:non-control { <-[\x00..\x1F\\]-stopper>+ {make ~$/}}
        token chars:escape { \\ {make '\\'}}
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
        token escape:sym<u> { <sym> <hex>**4 {make chr :16(@<hex>.join)}}
        token escape:sym<U> { <sym> <hex>**8 {make chr :16(@<hex>.join)}}
    }

    role Multi {
        token chars:newline { \n+ {make ~$/}}
        token escape:newline { \n\s* {make ""}}
    }

    token string:sym<'> {
        <sym> ~ <sym> <foreign-rule=.String::string>
        { make $<foreign-rule>.ast }
    }
    token string:sym<'''> {
        [<sym>\n?] ~ <sym>
        <foreign-rule: 'string', state$= String but role :: does Multi {
                token stopper { "'''" }
        }>
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

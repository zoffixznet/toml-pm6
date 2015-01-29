use MONKEY_TYPING;
augment class Grammar {
    method call-rule ($regex_name, $class) {
        my $cursor = $class.'!cursor_init'(self.orig(), :p(self.pos()));
        my $ret = $cursor."$regex_name"();
        self.MATCH.make: $ret.MATCH.ast;
        $ret;
    }
}

grammar TOML::Grammar {
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

    grammar Value {...}
    token key {
        <:L+:N+[_-]>+
        { make ~$/ }
    }

    grammar Value {
        token ws { [\n|' '|\t|'#'\N*]* }
        rule value {
            | <integer> { make $<digit>.ast  }
            | <float>  { make $<float>.ast  }
            | <array>  { make $<array>.ast  }
            | <bool>   { make $<bool>.ast   }
            | <datetime> { make $<datetime>.ast }
            # XXX Ugly
            | <string> { make $<string><call-rule>.ast }
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
        proto token string { * }

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
            <sym> ~ <sym> <call-rule: 'string', String>
        }
        token string:sym<'''> {
            [<sym>\n?] ~ <sym> <call-rule: 'string', String but Multi>
        }
        token string:sym<"> {
            <sym> ~ <sym>
            <call-rule: 'string', String but role :: does Escapes {
                    token stopper { \" }
            }>
        }
        token string:sym<"""> {
            [<sym>\n?] ~ <sym>
            <call-rule: 'string', String but role :: does Escapes does Multi {
                token stopper { '"""' }
            }>
        }
    }

    token value {
        <val=.Value::value> { make $<val>.ast }
    }
}

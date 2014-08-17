grammar TOML::Grammar::Value { ... }

grammar TOML::Grammar {
    token ws { [<[\ \t]>|'#'\N*]* }

    rule TOP {
        :my %top;
        ^ \n *
        [[
        | <keyvalue>    { %top{.key} =     .value given @<keyvalue>\  [*-1].ast }
        | <table>       { %top{.key} =     .value given @<table>\     [*-1].ast  }
        | <table_array> { %top{.key}.push: .value given @<table_array>[*-1].ast }
        ] \n * ]*
        $
        { make %top }
    }

    rule keyvalue {
        $<key>=[<-[\s#=\[\].]>*]
        '='
        <value>
    }

    rule table {
        '[' ~ ']' $<name>=[<-[\#\[\]\s]>+] \n
        <keyvalue> *
    }

    rule table_array {
        '[[' ~ ']]' $<name>=[<-[\#\[\]\s]>+] \n
        <keyvalue> *
    }

    token value {
        <val=.TOML::Grammar::Value::value> { say $/; make $<val>.ast }
    }
}

grammar TOML::Grammar::Value {
    token ws { [\n|' '|\t|'#'\N*]* }
    rule value {
        | <digit>  { make $<digit>.ast  }
        | <string> { make $<string>.ast }
        | <array>  { make $<array>.ast  }
        | <bool>   { make $<bool>.ast   }
    }
    token digit { \d+ { make +$/ } }
    token string { \" ~ \" $<str>=[<-["]>*] }
    rule array { \[ ~ \] <value> *% \, }
    token bool {
        | true { make True }
        | false { make False }
    }
}

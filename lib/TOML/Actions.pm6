class TOML::Actions;

=begin pod
method TOP ($/) {
    my %top;
    say $<hash>.perl;
    for @<hash> {
        if $_<keyvalue>.?ast // $_<table>.?ast -> $_ {
            %top{.key} = .value;
        }
        elsif $_<table_array>.?ast -> $_ {
            %top{.key}.push: .value;
        }
    }
    make %top;
}
=end pod

method keyvalue ($/) {
    make $<key>.Str => $<value>.ast
}

method table ($/) {
    my %table;
    %table{.key} = .value for @<keyvalue>».ast;
    make lol(|$<name>.Str.split('.')) => %table;
}

method table_array ($/) {
    my %table;
    %table{.key} = .value for @<keyvalue>».ast;
    make lol(|$<name>.Str.split('.')) => %table;
}

method array ($/) { make my@ = @<value>».ast }

method string ($/) { make $<str>.Str }

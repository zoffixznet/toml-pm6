module TOML;
use TOML::Grammar;

sub from-toml($text) is export {
    TOML::Grammar.parse($text).ast;
}

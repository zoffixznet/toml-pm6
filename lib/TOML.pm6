module TOML;
use TOML::Grammar;
use TOML::Actions;

sub from-toml($text) is export {
    TOML::Grammar.parse($text, :actions(TOML::Actions)).ast;
}

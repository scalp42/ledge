use Test::Nginx::Socket;
use Cwd qw(cwd);

plan tests => repeat_each() * (blocks() * 2); 

my $pwd = cwd();

$ENV{TEST_LEDGE_REDIS_DATABASE} ||= 1;

our $HttpConfig = qq{
	lua_package_path "$pwd/lib/?.lua;;";
	init_by_lua "
		ledge_mod = require 'ledge.ledge'
        ledge = ledge_mod:new()
		ledge.config.redis.database = 1
	";
};

run_tests();

__DATA__
=== TEST 1: Read and override globals from init
--- http_config eval: $::HttpConfig
--- config
	location /config_1 {
        content_by_lua '
            ngx.print(ledge.config.redis.database)
            ledge.config.redis.database = 2
            ngx.say(ledge.config.redis.database)
        ';
    }
--- request
GET /config_1
--- response_body
12

=== TEST 2: Module instance level config must not collide
--- http_config eval: $::HttpConfig
--- config
location /config_2 {
    content_by_lua '
        local ledge2 = ledge_mod:new()
        ledge.config.redis.database = 5
        ngx.say(ledge2.config.redis.database)
        ledge2.config.redis.database = 4
        ngx.say(ledge2.config.redis.database)
    ';
}
--- request
GET /config_2
--- response_body
0
4


=== TEST 3: Test that bad config options log an error
--- http_config eval: $::HttpConfig
--- config
location /config_3 {
    content_by_lua '
        local ledge2 = ledge_mod:new()
        ledge.config.bad_option = 5
    ';
}
--- request
GET /config_3
--- error_log
Unknown configuration option bad_option

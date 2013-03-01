use Test::Nginx::Socket;
use Cwd qw(cwd);

plan tests => repeat_each() * (blocks() * 2) - 1;

$ENV{TEST_LEDGE_REDIS_DATABASE} ||= 1;
my $pwd = cwd();

our $HttpConfig = qq{
	lua_package_path "$pwd/lib/?.lua;;";
    init_by_lua "
        ledge_mod = require 'ledge.ledge'
        ledge = ledge_mod:new()
        ledge.config.redis.database = $ENV{TEST_LEDGE_REDIS_DATABASE}
    ";
};

run_tests();

__DATA__
=== TEST 1: ORIGIN_MODE_NORMAL
--- http_config eval: $::HttpConfig
--- config
	location /origin_mode {
        content_by_lua '
            ledge.config.origin_mode = ledge.ORIGIN_MODE_NORMAL
            ledge:run()
        ';
    }
    location /__ledge_origin {
        more_set_headers  "Cache-Control: public, max-age=600";
        echo "OK";
    }
--- request
GET /origin_mode
--- response_body
OK


=== TEST 2: ORIGIN_MODE_AVOID
--- http_config eval: $::HttpConfig
--- config
	location /origin_mode {
        content_by_lua '
            ledge.config.origin_mode = ledge.ORIGIN_MODE_AVOID
            ledge:run()
        ';
    }
    location /__ledge_origin {
        echo "ORIGIN";
    }
--- more_headers
Cache-Control: no-cache
--- request
GET /origin_mode
--- response_body
OK


=== TEST 3: ORIGIN_MODE_BYPASS when cached
--- http_config eval: $::HttpConfig
--- config
	location /origin_mode {
        content_by_lua '
            ledge.config.origin_mode = ledge.ORIGIN_MODE_BYPASS
            ledge:run()
        ';
    }
    location /__ledge_origin {
        echo "ORIGIN";
    }
--- more_headers
Cache-Control: no-cache
--- request
GET /origin_mode
--- response_body
OK

=== TEST 4: ORIGIN_MODE_BYPASS when we have nothing
--- http_config eval: $::HttpConfig
--- config
	location /origin_mode_bypass {
        content_by_lua '
            ledge.config.origin_mode = ledge.ORIGIN_MODE_BYPASS
            ledge:run()
        ';
    }
    location /__ledge_origin {
        echo "ORIGIN";
    }
--- more_headers
Cache-Control: no-cache
--- request
GET /origin_mode_bypass
--- error_code: 503


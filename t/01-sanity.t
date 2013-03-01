use Test::Nginx::Socket;
use Cwd qw(cwd);

plan tests => repeat_each() * (blocks() * 3) - 1; 

my $pwd = cwd();

$ENV{TEST_LEDGE_REDIS_DATABASE} ||= 1;

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
=== TEST 1: Load module without errors.
--- http_config eval: $::HttpConfig
--- config
	location /sanity_1 {
        echo "OK";
    }
--- request
GET /sanity_1
--- no_error_log
[error]


=== TEST 2: Run module without errors, returning origin content.
--- http_config eval: $::HttpConfig
--- config
	location /sanity_2 {
        content_by_lua '
            ledge:run()
        ';
    }
    location /__ledge_origin {
        echo "OK";
    }
--- request
GET /sanity_2
--- no_error_log
[error]
--- response_body
OK


=== TEST 3: Check state machine "compiles".
--- http_config eval: $::HttpConfig
--- config
	location /sanity_2 {
        content_by_lua '
            for ev,t in pairs(ledge.events) do
                for _,trans in ipairs(t) do
                    -- Check states
                    for _,kw in ipairs { "when", "after", "begin" } do
                        if trans[kw] then
                            if "function" ~= type(ledge.states[trans[kw]]) then
                                ngx.say("State "..trans[kw].." requested during "..ev.." is not defined")
                            end
                        end
                    end

                    -- Check "in_case" previous event
                    if trans["in_case"] then
                        if not ledge.events[trans["in_case"]] then
                            ngx.say("Event "..trans["in_case"].." filtered for but is not in transition table")
                        end
                    end


                    -- Check actions
                    if trans["but_first"] then
                        if "function" ~= type(ledge.actions[trans["but_first"]]) then
                            ngx.say("Action "..trans["but_first"].." called during "..ev.." is not defined")
                        end
                    end
                end
            end

            for t,v in pairs(ledge.pre_transitions) do
                if "function" ~= type(ledge.states[t]) then
                    ngx.say("Pre-transitions defined for missing state "..t)
                end
                if not v["action"] then
                    ngx.say("No pre-transition actions defined for "..t)
                else
                    if "function" ~= type(ledge.actions[v["action"]]) then
                        ngx.say("Pre-transition action "..v["action"].." is not defined")
                    end
                end
            end

            ngx.say("OK")
        ';
    }
--- request
GET /sanity_2
--- no_error_log
[error]
--- response_body
OK

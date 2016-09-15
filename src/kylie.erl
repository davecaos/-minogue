  -module(kylie).

-author("David Cesar Hernan Cao <david.c.h.cao@gmail.com>").
-github("https://github.com/davecaos").
-license("MIT").

-export([ add/1
        , start/0
        , stop/0
        , delete/1
        , query/1
        , get_result/2
        , build_gremblin/1
        , build_gremblin_human_readable/1
        ]).

-define(WRITE_URI,          "/api/v1/write").
-define(WRITE_NQUAD_URI,    "/api/v1/write/file/nquad").
-define(DELETE_URI,         "/api/v1/delete").
-define(QUERY_GREMBLIN_URI, "/api/v1/query/gremlin").

start() -> ok.

stop() ->  ok.

add(Squad) ->
  JsonBody = jsx:encode([Squad]),
  {200, _Response} = cayley_http_call(?WRITE_URI, JsonBody).

delete(Squad) ->
  JsonBody = jsx:encode([Squad]),
  {200, _Response} = cayley_http_call(?DELETE_URI, JsonBody).

get_result(Subject, Predicate) ->
  Query = io_lib:format(<<"g.V('~s').Out('~s').All()">>, [Subject, Predicate]),
  query(Query).

filter_query_result(#{<<"result">> := null})    -> [];
filter_query_result(#{<<"result">> := Results}) ->
  Fun = 
    fun(#{<<"id">> := Contact}) -> 
      Contact 
    end,
  lists:map(Fun, Results).

build_gremblin_human_readable(PropLisps) ->
 erlang:iolist_to_binary(build_gremblin(PropLisps)).

build_gremblin(PropLisps) ->
 lists:map(fun build_query/1, PropLisps).

build_query({in, In}) ->
  io_lib:format(<<"In('~s').">>, [build_query(In)]);
build_query({out, Out}) ->
  io_lib:format(<<"Out('~s').">>, [build_query(Out)]);
build_query({graph_vertex, GraphVertex}) ->
  io_lib:format(<<"g.V('~s').">>, [build_query(GraphVertex)]);
build_query({graph_morphism, GraphMorphism}) ->
  io_lib:format(<<"g.M('~s').">>, [build_query(GraphMorphism)]);
build_query({graph_emit, Data}) ->
  io_lib:format(<<"g.Emit('~s').">>, [build_query(Data)]);

build_query({has, [Predicate, Object]}) ->
  io_lib:format(<<"Has('~s','~s' ).">>, [build_query(Predicate), build_query(Object)]);
build_query({get_limit, Limit}) ->
  io_lib:format(<<"GetLimit(~s).">>, [build_query(Limit)]);
build_query({skip, Skip}) ->
  io_lib:format(<<"Skip('~s').">>, [build_query(Skip)]);
build_query({follow, Follow}) ->
  io_lib:format(<<"Follow('~s').">>, [build_query(Follow)]);
build_query({followr, FollowR}) ->
  io_lib:format(<<"FollowR('~s').">>, [build_query(FollowR)]);
build_query({save, [Predicate, Tag]}) ->
  io_lib:format(<<"Save('~s','~s').">>, [build_query(Predicate), build_query(Tag)]);
build_query({intersect, Query}) ->
  io_lib:format(<<"Intersect(~s).">>, [build_query(Query)]);
build_query({union, Query}) ->
  io_lib:format(<<"Union('~s').">>, [build_query(Query)]);
build_query({except, Except}) ->
  io_lib:format(<<"Except('~s').">>, [build_query(Except)]);
build_query(all) ->
  <<"All()">>;
build_query(Node) ->
  Node.

query(Query) ->
  get_cayley_error(cayley_http_call(?QUERY_GREMBLIN_URI, Query)).

-spec cayley_http_call(string(), iodata()) -> map().
cayley_http_call(Uri, Body) ->
  {ok, Port} = application:get_env(kylie, port),
  {ok, Host}  = application:get_env(kylie, host),
  {ok, Timeout} = application:get_env(kylie, timeout),
  Headers = [{<<"Content-Type">>, <<"application/json">>}],
  List    = [Host, <<":">>, integer_to_list(Port), Uri],
  URL     = iolist_to_binary(List),
  Payload = Body,
  Options = [{timeout, Timeout}],
  {ok, StatusCode, _RespHeaders, ClientRef} =
    hackney:request(post, URL, Headers, Payload, Options),
  {ok, ResponseBody} = hackney:body(ClientRef),
  {StatusCode, ResponseBody}.

get_cayley_error({_StatusCode = 200, JsonResponse}) ->
  MapResponse = jsx:decode(JsonResponse, [return_maps]),
  {ok, filter_query_result(MapResponse)};
get_cayley_error({StatusErrorCode, ErrorDescription}) ->
  {error, {StatusErrorCode, ErrorDescription}}.


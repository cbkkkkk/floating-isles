-- 浮空岛群岛版 v3.1.3 · 云数据库初始化
-- 一个 DO 块 = 一条 SQL 语句，满足 exec_sql「单语句」限制。
-- 纪律：表不对 anon/authenticated 开放；全部读写经 SECURITY DEFINER 函数；client_id 不出库。

DO $mig$
BEGIN

EXECUTE $t1$ CREATE TABLE IF NOT EXISTS public.fi_islands (
  id text PRIMARY KEY,
  name text NOT NULL,
  author text NOT NULL DEFAULT '',
  description text NOT NULL DEFAULT '',
  client_id text NOT NULL DEFAULT '',
  builtin integer NOT NULL DEFAULT 0,
  html text,
  created_at timestamptz NOT NULL DEFAULT now()
) $t1$;
EXECUTE $t2$ CREATE TABLE IF NOT EXISTS public.fi_profiles (
  uid text PRIMARY KEY,
  name text NOT NULL,
  updated_at timestamptz NOT NULL DEFAULT now()
) $t2$;
EXECUTE $t3$ CREATE TABLE IF NOT EXISTS public.fi_msgs (
  id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  island_id text NOT NULL,
  client_id text NOT NULL DEFAULT '',
  author text NOT NULL DEFAULT '',
  body text NOT NULL,
  ts bigint NOT NULL DEFAULT 0,
  created_at timestamptz NOT NULL DEFAULT now()
) $t3$;
EXECUTE $t4$ CREATE TABLE IF NOT EXISTS public.fi_likes (
  island_id text NOT NULL,
  client_id text NOT NULL,
  PRIMARY KEY (island_id, client_id)
) $t4$;
EXECUTE $t5$ CREATE TABLE IF NOT EXISTS public.fi_stats (
  island_id text PRIMARY KEY,
  visits bigint NOT NULL DEFAULT 0,
  likes bigint NOT NULL DEFAULT 0
) $t5$;
EXECUTE $t6$ CREATE TABLE IF NOT EXISTS public.fi_dm (
  id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  island_id text NOT NULL DEFAULT '',
  from_cid text NOT NULL DEFAULT '',
  to_cid text NOT NULL DEFAULT '',
  author text NOT NULL DEFAULT '',
  body text NOT NULL DEFAULT '',
  rd integer NOT NULL DEFAULT 0,
  ts bigint NOT NULL DEFAULT 0
) $t6$;

EXECUTE $r1$ ALTER TABLE public.fi_islands ENABLE ROW LEVEL SECURITY $r1$;
EXECUTE $r2$ ALTER TABLE public.fi_profiles ENABLE ROW LEVEL SECURITY $r2$;
EXECUTE $r3$ ALTER TABLE public.fi_msgs ENABLE ROW LEVEL SECURITY $r3$;
EXECUTE $r4$ ALTER TABLE public.fi_likes ENABLE ROW LEVEL SECURITY $r4$;
EXECUTE $r5$ ALTER TABLE public.fi_stats ENABLE ROW LEVEL SECURITY $r5$;
EXECUTE $r6$ ALTER TABLE public.fi_dm ENABLE ROW LEVEL SECURITY $r6$;

EXECUTE $f1$
CREATE OR REPLACE FUNCTION public.fi_world(p_cid text)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp
AS $body$
DECLARE who text; nm text; cid text; arr jsonb;
BEGIN
  who := coalesce(auth.uid()::text, '');
  cid := coalesce(p_cid, '');
  nm := '';
  IF who <> '' THEN SELECT name INTO nm FROM fi_profiles WHERE uid = who; END IF;
  SELECT coalesce(jsonb_agg(jsonb_build_object(
    'id', i.id, 'name', i.name, 'author', i.author, 'desc', i.description,
    'builtin', i.builtin,
    'mine', (i.client_id <> '' AND (i.client_id = cid OR (who <> '' AND i.client_id = who))),
    'hasHtml', (i.html IS NOT NULL AND length(i.html) > 0),
    'visits', coalesce(s.visits, 0), 'likes', coalesce(s.likes, 0)
  ) ORDER BY i.created_at, i.id), '[]'::jsonb)
  INTO arr FROM fi_islands i LEFT JOIN fi_stats s ON s.island_id = i.id;
  RETURN jsonb_build_object('ok', 1, 'islands', arr, 'who', who,
    'pname', coalesce(nm, ''), 'unread', 0);
END $body$;
$f1$;

EXECUTE $f2$
CREATE OR REPLACE FUNCTION public.fi_me()
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp
AS $body$
DECLARE who text; nm text;
BEGIN
  who := coalesce(auth.uid()::text, '');
  IF who = '' THEN RETURN jsonb_build_object('ok', 0); END IF;
  SELECT name INTO nm FROM fi_profiles WHERE uid = who;
  RETURN jsonb_build_object('ok', 1, 'name', coalesce(nm, ''));
END $body$;
$f2$;

EXECUTE $f3$
CREATE OR REPLACE FUNCTION public.fi_set_name(p_name text)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp
AS $body$
DECLARE who text; v text;
BEGIN
  who := coalesce(auth.uid()::text, '');
  v := btrim(coalesce(p_name, ''));
  IF who = '' THEN RETURN jsonb_build_object('ok', 0, 'err', 'noauth'); END IF;
  IF char_length(v) < 1 THEN RETURN jsonb_build_object('ok', 0, 'err', 'bad'); END IF;
  IF char_length(v) > 12 THEN RETURN jsonb_build_object('ok', 0, 'err', 'long'); END IF;
  INSERT INTO fi_profiles (uid, name, updated_at) VALUES (who, v, now())
  ON CONFLICT (uid) DO UPDATE SET name = EXCLUDED.name, updated_at = now();
  RETURN jsonb_build_object('ok', 1, 'name', v);
END $body$;
$f3$;

EXECUTE $f4$
CREATE OR REPLACE FUNCTION public.fi_claim(p_old text)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp
AS $body$
DECLARE who text; a integer; b integer;
BEGIN
  who := coalesce(auth.uid()::text, '');
  IF who = '' OR p_old IS NULL OR length(p_old) < 8 THEN
    RETURN jsonb_build_object('ok', 0, 'm', 0, 'i', 0, 'l', 0);
  END IF;
  UPDATE fi_msgs SET client_id = who WHERE client_id = p_old;
  GET DIAGNOSTICS a = ROW_COUNT;
  UPDATE fi_islands SET client_id = who WHERE client_id = p_old AND builtin = 0;
  GET DIAGNOSTICS b = ROW_COUNT;
  RETURN jsonb_build_object('ok', 1, 'm', a, 'i', b, 'l', 0);
END $body$;
$f4$;

EXECUTE $f5$
CREATE OR REPLACE FUNCTION public.fi_msgs_list(p_island text, p_cid text, p_limit integer)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp
AS $body$
DECLARE arr jsonb; who text; cid text;
BEGIN
  who := coalesce(auth.uid()::text, '');
  cid := coalesce(p_cid, '');
  SELECT coalesce(jsonb_agg(jsonb_build_object(
    'id', m.id, 'a', m.author, 't', m.body, 'ts', m.ts,
    'mine', (m.client_id = cid OR (who <> '' AND m.client_id = who))
  ) ORDER BY m.id), '[]'::jsonb)
  INTO arr FROM (
    SELECT * FROM fi_msgs WHERE island_id = coalesce(p_island, '')
    ORDER BY id DESC LIMIT LEAST(coalesce(p_limit, 200), 200)
  ) m;
  RETURN jsonb_build_object('ok', 1, 'msgs', arr);
END $body$;
$f5$;

EXECUTE $f6$
CREATE OR REPLACE FUNCTION public.fi_msg_add(p_island text, p_cid text, p_author text, p_body text)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp
AS $body$
DECLARE nid bigint; who text; v text; ts bigint;
BEGIN
  v := btrim(coalesce(p_body, ''));
  IF char_length(v) < 1 OR char_length(v) > 200 THEN
    RETURN jsonb_build_object('ok', 0, 'err', 'bad');
  END IF;
  who := coalesce(nullif(auth.uid()::text, ''), coalesce(p_cid, ''));
  ts := (extract(epoch from now()) * 1000)::bigint;
  INSERT INTO fi_msgs (island_id, client_id, author, body, ts)
  VALUES (coalesce(p_island, ''), who, coalesce(nullif(p_author, ''), '@匿名'), v, ts)
  RETURNING id INTO nid;
  RETURN jsonb_build_object('ok', 1, 'id', nid, 'ts', ts);
END $body$;
$f6$;

EXECUTE $f7$
CREATE OR REPLACE FUNCTION public.fi_msg_dm(p_island text, p_cid text, p_body text)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp
AS $body$
DECLARE who text; owner text; v text; ts bigint;
BEGIN
  v := btrim(coalesce(p_body, ''));
  IF char_length(v) < 1 OR char_length(v) > 200 THEN
    RETURN jsonb_build_object('ok', 0, 'err', 'bad');
  END IF;
  who := coalesce(nullif(auth.uid()::text, ''), coalesce(p_cid, ''));
  SELECT client_id INTO owner FROM fi_islands WHERE id = coalesce(p_island, '');
  ts := (extract(epoch from now()) * 1000)::bigint;
  INSERT INTO fi_dm (island_id, from_cid, to_cid, author, body, ts)
  VALUES (coalesce(p_island, ''), who, coalesce(owner, ''), '@云海', v, ts);
  RETURN jsonb_build_object('ok', 1);
END $body$;
$f7$;

EXECUTE $f8$
CREATE OR REPLACE FUNCTION public.fi_inbox(p_limit integer)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp
AS $body$
DECLARE who text; arr jsonb; unread integer;
BEGIN
  who := coalesce(auth.uid()::text, '');
  IF who = '' THEN RETURN jsonb_build_object('ok', 1, 'msgs', '[]'::jsonb, 'unread', 0); END IF;
  SELECT coalesce(jsonb_agg(jsonb_build_object(
    'id', d.id, 'dir', CASE WHEN d.to_cid = who THEN 'in' ELSE 'out' END,
    'rd', d.rd, 'a', d.author, 't', d.body, 'ts', d.ts
  ) ORDER BY d.id), '[]'::jsonb)
  INTO arr FROM (
    SELECT * FROM fi_dm WHERE to_cid = who OR from_cid = who
    ORDER BY id DESC LIMIT LEAST(coalesce(p_limit, 100), 100)
  ) d;
  SELECT count(*)::integer INTO unread FROM fi_dm WHERE to_cid = who AND rd = 0;
  RETURN jsonb_build_object('ok', 1, 'msgs', arr, 'unread', unread);
END $body$;
$f8$;

EXECUTE $f9$
CREATE OR REPLACE FUNCTION public.fi_inbox_seen(p_id bigint)
RETURNS integer LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp
AS $body$
DECLARE who text;
BEGIN
  who := coalesce(auth.uid()::text, '');
  IF who = '' THEN RETURN 0; END IF;
  UPDATE fi_dm SET rd = 1 WHERE to_cid = who AND (coalesce(p_id, 0) = 0 OR id = p_id);
  RETURN 1;
END $body$;
$f9$;

EXECUTE $f10$
CREATE OR REPLACE FUNCTION public.fi_island_add(
  p_id text, p_cid text, p_name text, p_author text, p_desc text, p_b64 text)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp
AS $body$
DECLARE who text; doc text;
BEGIN
  IF p_id IS NULL OR length(p_id) < 1 OR p_name IS NULL OR char_length(btrim(p_name)) < 1
     OR char_length(btrim(p_name)) > 16 OR p_b64 IS NULL OR length(p_b64) < 10 THEN
    RETURN jsonb_build_object('ok', 0, 'err', 'bad');
  END IF;
  who := coalesce(nullif(auth.uid()::text, ''), coalesce(p_cid, ''));
  IF length(who) < 8 THEN RETURN jsonb_build_object('ok', 0, 'err', 'noauth'); END IF;
  doc := convert_from(decode(p_b64, 'base64'), 'UTF8');
  INSERT INTO fi_islands (id, name, author, description, client_id, builtin, html)
  VALUES (p_id, btrim(p_name), coalesce(p_author, ''), coalesce(p_desc, ''), who, 0, doc)
  ON CONFLICT (id) DO UPDATE SET
    name = EXCLUDED.name, author = EXCLUDED.author,
    description = EXCLUDED.description, html = EXCLUDED.html
  WHERE fi_islands.client_id = who AND fi_islands.builtin = 0;
  RETURN jsonb_build_object('ok', 1, 'id', p_id);
END $body$;
$f10$;

EXECUTE $f11$
CREATE OR REPLACE FUNCTION public.fi_island_html(p_id text)
RETURNS text LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp
AS $body$
DECLARE doc text;
BEGIN
  SELECT html INTO doc FROM fi_islands WHERE id = coalesce(p_id, '');
  RETURN coalesce(doc, '');
END $body$;
$f11$;

EXECUTE $f12$
CREATE OR REPLACE FUNCTION public.fi_del_island(p_id text, p_cid text)
RETURNS integer LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp
AS $body$
DECLARE k integer; who text;
BEGIN
  who := coalesce(nullif(auth.uid()::text, ''), coalesce(p_cid, ''));
  DELETE FROM fi_islands WHERE id = coalesce(p_id, '') AND client_id = who AND builtin = 0;
  GET DIAGNOSTICS k = ROW_COUNT;
  IF k > 0 THEN
    DELETE FROM fi_msgs WHERE island_id = p_id;
    DELETE FROM fi_likes WHERE island_id = p_id;
    DELETE FROM fi_stats WHERE island_id = p_id;
  END IF;
  RETURN k;
END $body$;
$f12$;

EXECUTE $f13$
CREATE OR REPLACE FUNCTION public.fi_del_msg(p_id bigint, p_cid text)
RETURNS integer LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp
AS $body$
DECLARE k integer; who text;
BEGIN
  who := coalesce(nullif(auth.uid()::text, ''), coalesce(p_cid, ''));
  DELETE FROM fi_msgs WHERE id = p_id AND client_id = who;
  GET DIAGNOSTICS k = ROW_COUNT;
  RETURN k;
END $body$;
$f13$;

EXECUTE $f14$
CREATE OR REPLACE FUNCTION public.fi_visit(p_island text)
RETURNS bigint LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp
AS $body$
DECLARE n bigint;
BEGIN
  IF p_island IS NULL OR length(p_island) < 1 THEN RETURN 0; END IF;
  INSERT INTO fi_stats (island_id, visits, likes) VALUES (p_island, 1, 0)
  ON CONFLICT (island_id) DO UPDATE SET visits = fi_stats.visits + 1;
  SELECT visits INTO n FROM fi_stats WHERE island_id = p_island;
  RETURN coalesce(n, 0);
END $body$;
$f14$;

EXECUTE $f15$
CREATE OR REPLACE FUNCTION public.fi_like(p_island text, p_cid text)
RETURNS bigint LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp
AS $body$
DECLARE n bigint; who text;
BEGIN
  who := coalesce(nullif(auth.uid()::text, ''), coalesce(p_cid, ''));
  IF p_island IS NULL OR length(who) < 8 THEN RETURN 0; END IF;
  INSERT INTO fi_likes (island_id, client_id) VALUES (p_island, who) ON CONFLICT DO NOTHING;
  INSERT INTO fi_stats (island_id, visits, likes)
  VALUES (p_island, 0, (SELECT count(*) FROM fi_likes WHERE island_id = p_island))
  ON CONFLICT (island_id) DO UPDATE
    SET likes = (SELECT count(*) FROM fi_likes WHERE island_id = p_island);
  SELECT likes INTO n FROM fi_stats WHERE island_id = p_island;
  RETURN coalesce(n, 0);
END $body$;
$f15$;

EXECUTE $f16$
CREATE OR REPLACE FUNCTION public.fi_unlike(p_island text, p_cid text)
RETURNS bigint LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp
AS $body$
DECLARE n bigint; who text;
BEGIN
  who := coalesce(nullif(auth.uid()::text, ''), coalesce(p_cid, ''));
  DELETE FROM fi_likes WHERE island_id = p_island AND client_id = who;
  INSERT INTO fi_stats (island_id, visits, likes)
  VALUES (p_island, 0, (SELECT count(*) FROM fi_likes WHERE island_id = p_island))
  ON CONFLICT (island_id) DO UPDATE
    SET likes = (SELECT count(*) FROM fi_likes WHERE island_id = p_island);
  SELECT likes INTO n FROM fi_stats WHERE island_id = p_island;
  RETURN coalesce(n, 0);
END $body$;
$f16$;

GRANT EXECUTE ON FUNCTION public.fi_world(text) TO authenticated, anon;
GRANT EXECUTE ON FUNCTION public.fi_me() TO authenticated, anon;
GRANT EXECUTE ON FUNCTION public.fi_set_name(text) TO authenticated, anon;
GRANT EXECUTE ON FUNCTION public.fi_claim(text) TO authenticated, anon;
GRANT EXECUTE ON FUNCTION public.fi_msgs_list(text, text, integer) TO authenticated, anon;
GRANT EXECUTE ON FUNCTION public.fi_msg_add(text, text, text, text) TO authenticated, anon;
GRANT EXECUTE ON FUNCTION public.fi_msg_dm(text, text, text) TO authenticated, anon;
GRANT EXECUTE ON FUNCTION public.fi_inbox(integer) TO authenticated, anon;
GRANT EXECUTE ON FUNCTION public.fi_inbox_seen(bigint) TO authenticated, anon;
GRANT EXECUTE ON FUNCTION public.fi_island_add(text, text, text, text, text, text) TO authenticated, anon;
GRANT EXECUTE ON FUNCTION public.fi_island_html(text) TO authenticated, anon;
GRANT EXECUTE ON FUNCTION public.fi_del_island(text, text) TO authenticated, anon;
GRANT EXECUTE ON FUNCTION public.fi_del_msg(bigint, text) TO authenticated, anon;
GRANT EXECUTE ON FUNCTION public.fi_visit(text) TO authenticated, anon;
GRANT EXECUTE ON FUNCTION public.fi_like(text, text) TO authenticated, anon;
GRANT EXECUTE ON FUNCTION public.fi_unlike(text, text) TO authenticated, anon;

END $mig$;

/*Part II: DDL*/
/*As additional comment to the following code, we have decided to limit such text
fields which the exercise statement doesn't say anything about them, since they
are opened to be filled in with as much data as you can. Therefore, we ensure
data consistency about the input we expect to receive.*/
\set AUTOCOMMIT off
BEGIN;
CREATE TABLE "usernames" (
  "id" SERIAL PRIMARY KEY,
  "username" VARCHAR(25) NOT NULL,
  CONSTRAINT "username_empty" CHECK (LENGTH(TRIM("username")) > 0),
  "last_login" TIMESTAMP WITH TIME ZONE DEFAULT NULL
);
CREATE UNIQUE INDEX "usernames_index" ON "usernames" (LOWER("username"));

CREATE TABLE "topics" (
  "id" SERIAL PRIMARY KEY,
  "topic" VARCHAR(30) NOT NULL,
  CONSTRAINT "topic_empty" CHECK (LENGTH(TRIM("topic")) > 0),
  "description" VARCHAR(500) DEFAULT NULL
);
CREATE UNIQUE INDEX "topics_index" ON "topics" (LOWER("topic"));

CREATE TABLE "posts" (
  "id" SERIAL PRIMARY KEY,
  "created_date" TIMESTAMP WITH TIME ZONE,
  "updated_date" TIMESTAMP WITH TIME ZONE,
  "username_id" INTEGER REFERENCES "usernames" ("id") ON DELETE SET NULL,
  "topic_id" INTEGER REFERENCES "topics" ("id") ON DELETE CASCADE,
  "title" VARCHAR(100) NOT NULL,
  CONSTRAINT "title_empty" CHECK (LENGTH(TRIM("title")) > 0),
  "url" VARCHAR(500),
  CONSTRAINT "check_url_text" CHECK(("text_content" IS NULL AND "url" IS NOT NULL)
    OR ("url" IS NULL AND "text_content" IS NOT NULL)),
  "text_content" VARCHAR(5000),
  CONSTRAINT "check_text_url" CHECK (("url" IS NULL AND "text_content" IS NOT NULL)
    OR ("text_content" IS NULL AND "url" IS NOT NULL))
);

CREATE INDEX "post_url_index" ON "posts" ("url");

CREATE TABLE "comments" (
  "id" SERIAL PRIMARY KEY,
  "created_date" TIMESTAMP WITH TIME ZONE,
  "updated_date" TIMESTAMP WITH TIME ZONE,
  "text_content" VARCHAR(1000) NOT NULL,
  CONSTRAINT "text_content_empty" CHECK (LENGTH(TRIM("text_content")) > 0),
  "replied_comment_id" INTEGER DEFAULT NULL REFERENCES "comments" ("id")
    ON DELETE CASCADE,
  "post_id" INTEGER REFERENCES "posts" ("id") ON DELETE CASCADE,
  "username_id" INTEGER REFERENCES "usernames" ("id") ON DELETE SET NULL
);

/*Here, contrary to what was stated in the 4th Guideline, I considered better to
have a composite primary key with the username_id and the post_id to ensure that
each user can only upvote or up_down_vote a post once, rather than add a surrogate
key in a SERIAL column, which would yield the same result. I don't see the point
to add a SERIAL column here to end up with the same result.*/
CREATE TABLE "up_down_votes" (
  "post_id" INTEGER REFERENCES "posts" ("id") ON DELETE CASCADE,
  "username_id" INTEGER REFERENCES "usernames" ("id") ON DELETE SET NULL,
  "up_down_vote" INTEGER NOT NULL,
  CONSTRAINT "up_down_values" CHECK ("up_down_vote" BETWEEN -1 AND 1),
  PRIMARY KEY("post_id", "username_id")
);

CREATE INDEX "up_down_votes_index" ON "up_down_votes" ("up_down_vote");

COMMIT;




/*Part III: DML & DQL*/
/*1st new table: "usernames"*/
BEGIN;
INSERT INTO "usernames" ("username") (
  SELECT bp.username
  FROM bad_posts bp
  UNION
  SELECT bc.username
  FROM bad_comments bc
  UNION
  SELECT REGEXP_SPLIT_TO_TABLE(bp.upvotes, ',')
  FROM bad_posts bp
  UNION
  SELECT REGEXP_SPLIT_TO_TABLE(bp.downvotes, ',')
  FROM bad_posts bp
);


/*2nd new table: "topics"*/
INSERT INTO "topics" ("topic") (
  SELECT DISTINCT INITCAP(topic)
  FROM bad_posts
);


/*3rd table: "posts"*/
/*Since there are titles longer than 100 characters, we decide
to cut the title  at 100-length limit to be able to fit them
in with the new title-VARCHAR(100). In addition to this,
we decide to follow the same criteria in terms of date,
stating the date column with the current date.*/
INSERT INTO "posts" ("username_id", "topic_id", "title", "url", "text_content") (
  (SELECT u.id, t.id, LEFT(bp.title, 100), bp.url, bp.text_content
  FROM bad_posts bp
  JOIN usernames u
    ON u.username = bp.username
  JOIN topics t
    ON t.topic = INITCAP(bp.topic))
);

UPDATE "posts" SET "created_date" = (SELECT CURRENT_DATE);
UPDATE "posts" SET "updated_date" = (SELECT CURRENT_DATE);


/*4th table: "comments"*/
INSERT INTO "comments" ("text_content", "post_id", "username_id") (
  SELECT bc.text_content, p.id, u.id
  FROM bad_comments bc
  JOIN bad_posts bp
    ON bc.post_id = bp.id
  JOIN posts p
    ON p.title = LEFT(bp.title, 100)
  JOIN usernames u
    ON bc.username = u.username
);

/*As in the previous cases, we use the same criteria to fill in
the new "date" column with the current date, since we don't
have date information anywhere.*/
UPDATE "comments" SET "created_date" = (SELECT CURRENT_DATE);
UPDATE "comments" SET "updated_date" = (SELECT CURRENT_DATE);


/*5th table: "up_down_votes"*/
/*First, we deem to add 2 temporary additional tables to
store the "upvotes" and the "downvotes" which are still
as String in the "bad_posts" table, separated between
them with commas. We create index in these temporary
tables in order to increase the overall performance.*/
CREATE TABLE "up_votes_temp" (
  "post_id" INTEGER,
  "name" VARCHAR,
  "username_id" INTEGER,
  "value" INTEGER DEFAULT 1
);

CREATE INDEX ON "up_votes_temp" ("post_id", "name");
CREATE INDEX ON "up_votes_temp" ("name");

INSERT INTO "up_votes_temp" ("post_id", "name", "username_id") (
  WITH t1 AS  (SELECT DISTINCT p.id AS new_post_id,
                REGEXP_SPLIT_TO_TABLE(bp.upvotes, ',') AS name
              FROM bad_posts bp
              JOIN posts p
                ON LEFT(bp.title, 100) = p.title)
  SELECT t1.new_post_id, t1.name, u.id
  FROM t1
  JOIN usernames u
    ON t1.name = u.username
);

CREATE TABLE "down_votes_temp" (
  "post_id" INTEGER,
  "name" VARCHAR,
  "username_id" INTEGER,
  "value" INTEGER DEFAULT -1
);

CREATE INDEX ON "down_votes_temp" ("post_id", "name");
CREATE INDEX ON "down_votes_temp" ("name");

INSERT INTO "down_votes_temp" ("post_id", "name", "username_id") (
  WITH t1 AS  (SELECT DISTINCT p.id AS new_post_id,
                REGEXP_SPLIT_TO_TABLE(bp.downvotes, ',') AS name
              FROM bad_posts bp
              JOIN posts p
                ON LEFT(bp.title, 100) = p.title)
  SELECT t1.new_post_id, t1.name, u.id
  FROM t1
  JOIN usernames u
    ON t1.name = u.username
);

INSERT INTO "up_down_votes" ("post_id", "username_id", "up_down_vote") (
      SELECT uv.post_id, uv.username_id, uv.value
      FROM up_votes_temp uv
    UNION
      SELECT dv.post_id, dv.username_id, dv.value
      FROM down_votes_temp dv
    ORDER BY 1, 2
);
COMMIT;

/*Finally, we drop the tables that we don't need anymore, since
they have accomplished their purpose.*/
BEGIN;
DROP TABLE "bad_posts";
DROP TABLE "bad_comments";
DROP TABLE "up_votes_temp";
DROP TABLE "down_votes_temp";
COMMIT;

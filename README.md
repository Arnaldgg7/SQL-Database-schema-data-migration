# SQL-Database-schema-data-migration
This is a Postgres SQL project from a Social News Aggregator on a website, based on the improvement of a previous SQL structure by means of a new SQL Database design schema, as well as the SQL statements necessary to migrate the previous data.

Udiddit, a social news aggregation, web content rating, and discussion website, was currently
using a risky and unreliable Postgres database schema to store the forum posts,
discussions, and votes made by their users about different topics.

The new created schema allow posts to be created by registered users on certain topics, and can
include a URL or a text content. It also allows registered users to cast an upvote (like) or
downvote (dislike) for any forum post that has been created. In addition to this, the schema
also allows registered users to add comments on posts.

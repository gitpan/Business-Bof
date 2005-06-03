-- FrameWork
-- Tables for the Business Oriented Framework
-- Copyright (c) 2004-2005 Kaare Rasmussen
-- This work is released under the GPL
-- $Id: create_tables_framework.sql,v 1.1 2005/05/28 19:02:11 kaare Exp $

--Tables
DROP TABLE fw_database;
DROP TABLE fw_user;
DROP TABLE fw_usergroup;
DROP TABLE fw_useringroup;
DROP TABLE fw_menulink;
DROP TABLE fw_menu;
DROP TABLE fw_usermenu;
DROP TABLE fw_task;
DROP TABLE fw_schedule;

CREATE TABLE fw_database (
       db_id                integer NOT NULL,
       dbtype               text,
       dbname               text,
       dbusername           text,
       dbpassword           text,
       dbhost               text,
       dbschema             text,
       updated              timestamp NOT NULL DEFAULT now,
 PRIMARY KEY (db_id )
);

CREATE TABLE fw_user (
       user_id              integer NOT NULL,
       name                 text,
       password             text,
       updated              timestamp NOT NULL DEFAULT now,
 PRIMARY KEY (user_id)
);

CREATE TABLE fw_usergroup (
       usergroup_id         integer NOT NULL,
       name                 text,
       db_id                integer,
       domainname           text,
       updated              timestamp NOT NULL DEFAULT now,
 PRIMARY KEY (usergroup_id),
 FOREIGN KEY (db_id)   REFERENCES fw_database
);

CREATE TABLE fw_useringroup (
       user_id              integer NOT NULL,
       usergroup_id         integer NOT NULL,
       updated              timestamp NOT NULL DEFAULT now,
 FOREIGN KEY (user_id)   REFERENCES fw_user,
 FOREIGN KEY (usergroup_id) REFERENCES fw_usergroup
);

CREATE TABLE fw_menu (
       menu_id              integer NOT NULL,
       name                 text,
       uri                  text,
       updated              timestamp NOT NULL DEFAULT now,
 PRIMARY KEY (menu_id )
);

CREATE TABLE fw_menulink (
       menulink_id          integer NOT NULL PRIMARY KEY,
       parent_id            integer NOT NULL,
       child_id             integer NOT NULL,
       updated              timestamp NOT NULL DEFAULT now,
 FOREIGN KEY (parent_id)   REFERENCES fw_menu,
 FOREIGN KEY (child_id)    REFERENCES fw_menu
);

CREATE TABLE fw_usermenu (
       usergroup_id         integer NOT NULL,
       menu_id              integer NOT NULL,
       updated              timestamp NOT NULL DEFAULT now,
 FOREIGN KEY (usergroup_id) REFERENCES fw_usergroup,
 FOREIGN KEY (menu_id)      REFERENCES fw_menu
);

CREATE TABLE fw_task (
       task_id              integer NOT NULL PRIMARY KEY,
       user_id              integer NOT NULL REFERENCES fw_user,
       transaction_id       integer NOT NULL,
       function             text,
       title                text,
       parameters           text,
       result               text,
       resulttype           text,
       status               integer NOT NULL,
       updated              timestamp NOT NULL DEFAULT now
);


CREATE TABLE fw_schedule (
       schedule_id          integer NOT NULL PRIMARY KEY,
       title                text,
       schedtype            text,
       schedule             text,
       user_id              integer NOT NULL REFERENCES fw_user,
       function             text,
       parameters           text,
       result               text,
       resulttype           text,
       lastrun              timestamp,
       updated              timestamp NOT NULL DEFAULT now
);

-- Views

-- Functions

-- Triggers


-- FrameWork
-- Tables for the Business Oriented Framework
-- Copyright (c) 2004-2005 Kaare Rasmussen
-- This work is released under the GPL
-- $Id: create_tables_framework.sql,v 1.1 2005/05/28 19:02:11 kaare Exp $

-- Sequences
DROP SEQUENCE fw_dbsequence;
DROP SEQUENCE fw_usersequence;
DROP SEQUENCE fw_usergroupsequence;
DROP SEQUENCE fw_menusequence;
DROP SEQUENCE fw_menulinksequence;
DROP SEQUENCE fw_tasksequence;
DROP SEQUENCE fw_transsequence;
DROP SEQUENCE fw_schedulesequence;

CREATE SEQUENCE fw_dbsequence INCREMENT 1;
CREATE SEQUENCE fw_usersequence INCREMENT 1;
CREATE SEQUENCE fw_usergroupsequence INCREMENT 1;
CREATE SEQUENCE fw_menusequence INCREMENT 1;
CREATE SEQUENCE fw_menulinksequence INCREMENT 1;
CREATE SEQUENCE fw_tasksequence INCREMENT 1;
CREATE SEQUENCE fw_transsequence INCREMENT 1;
CREATE SEQUENCE fw_schedulesequence INCREMENT 1;

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
       db_id                integer NOT NULL DEFAULT nextval('fw_dbsequence'),
       dbtype               text,
       dbname               text,
       dbusername           text,
       dbpassword           text,
       dbhost               text,
       dbschema             text,
       updated              timestamp NOT NULL DEFAULT now(),
 PRIMARY KEY (db_id )
);

COMMENT ON TABLE fw_database IS 'Business Database information';
COMMENT ON COLUMN fw_database.db_id IS 'Unique identifikation';
COMMENT ON COLUMN fw_database.dbname IS 'Database Name';
COMMENT ON COLUMN fw_database.dbusername IS 'User Name';
COMMENT ON COLUMN fw_database.dbpassword  IS 'Password';
COMMENT ON COLUMN fw_database.updated IS 'Timestamp for latest update of this row';

CREATE TABLE fw_user (
       user_id              integer NOT NULL DEFAULT nextval('fw_usersequence'),
       name                 text,
       password             text,
       updated              timestamp NOT NULL DEFAULT now(),
 PRIMARY KEY (user_id)
);

COMMENT ON TABLE fw_user IS 'User information';
COMMENT ON COLUMN fw_user.user_id IS 'Unique identifikation';
COMMENT ON COLUMN fw_user.name IS 'User Name';
COMMENT ON COLUMN fw_user.password IS 'Password';
COMMENT ON COLUMN fw_user.contact_id IS 'Contact information for user in fw_database';
COMMENT ON COLUMN fw_user.updated IS 'Timestamp for latest update of this row';

CREATE TABLE fw_usergroup (
       usergroup_id         integer NOT NULL DEFAULT nextval('fw_usergroupsequence'),
       name                 text,
       db_id                integer,
       domainname           text,
       updated              timestamp NOT NULL DEFAULT now(),
 PRIMARY KEY (usergroup_id),
 FOREIGN KEY (db_id)   REFERENCES fw_database
);

COMMENT ON TABLE fw_usergroup IS 'User Group information';
COMMENT ON COLUMN fw_usergroup.usergroup_id IS 'Unique identifikation';
COMMENT ON COLUMN fw_usergroup.name IS 'User Name';
COMMENT ON COLUMN fw_usergroup.db_id IS 'Reference to fw_database';
COMMENT ON COLUMN fw_usergroup.domainname IS 'Name of Domain (Company)';
COMMENT ON COLUMN fw_usergroup.updated IS 'Timestamp for latest update of this row';

CREATE TABLE fw_useringroup (
       user_id              integer NOT NULL,
       usergroup_id         integer NOT NULL,
       updated              timestamp NOT NULL DEFAULT now(),
 FOREIGN KEY (user_id)   REFERENCES fw_user,
 FOREIGN KEY (usergroup_id) REFERENCES fw_usergroup
);

COMMENT ON TABLE fw_useringroup IS 'Linking Users to Groups';
COMMENT ON COLUMN fw_useringroup.user_id IS 'Reference to fw_user';
COMMENT ON COLUMN fw_useringroup.usergroup_id IS 'Reference to fw_usergroup';
COMMENT ON COLUMN fw_useringroup.updated IS 'Timestamp for latest update of this row';

CREATE TABLE fw_menu (
       menu_id              integer NOT NULL DEFAULT nextval('fw_menusequence'),
       name                 text,
       uri                  text,
       updated              timestamp NOT NULL DEFAULT now(),
 PRIMARY KEY (menu_id )
);

COMMENT ON TABLE fw_menu IS 'Menu information';
COMMENT ON COLUMN fw_menu.menu_id IS 'Unique identifikation';
COMMENT ON COLUMN fw_menu.name IS 'Menu Name';
COMMENT ON COLUMN fw_menu.uri IS 'Link Name';
COMMENT ON COLUMN fw_menu.updated IS 'Timestamp for latest update of this row';

CREATE TABLE fw_menulink (
       menulink_id          integer NOT NULL DEFAULT nextval('fw_menulinksequence'),
       parent_id            integer NOT NULL,
       child_id             integer NOT NULL,
       updated              timestamp NOT NULL DEFAULT now(),
 FOREIGN KEY (parent_id)   REFERENCES fw_menu,
 FOREIGN KEY (child_id)    REFERENCES fw_menu
);

COMMENT ON TABLE fw_menulink IS 'linking Menus together';
COMMENT ON COLUMN fw_menulink.menulink_id IS 'Unique identification';
COMMENT ON COLUMN fw_menulink.parent_id IS 'Parent Menu';
COMMENT ON COLUMN fw_menulink.child_id IS 'Child Menu';
COMMENT ON COLUMN fw_menulink.updated IS 'Timestamp for latest update of this row';

CREATE TABLE fw_usermenu (
       usergroup_id         integer NOT NULL,
       menu_id              integer NOT NULL,
       updated              timestamp NOT NULL DEFAULT now(),
 FOREIGN KEY (usergroup_id) REFERENCES fw_usergroup,
 FOREIGN KEY (menu_id)      REFERENCES fw_menu
);

COMMENT ON TABLE fw_usermenu IS 'Linking Usergroups to Menus';
COMMENT ON COLUMN fw_usermenu.usergroup_id IS 'Reference to fw_usergroup';
COMMENT ON COLUMN fw_usermenu.menu_id IS 'Reference to fw_menu';
COMMENT ON COLUMN fw_usermenu.updated IS 'Timestamp for latest update of this row';

CREATE TABLE fw_task (
       task_id              integer NOT NULL DEFAULT nextval('fw_tasksequence')
                            PRIMARY KEY,
       user_id              integer NOT NULL REFERENCES fw_user,
       transaction_id       integer NOT NULL DEFAULT nextval('fw_transsequence'),
       function             text,
       title                text,
       parameters           text,
       result               text,
       resulttype           text,
       status               integer NOT NULL,
       updated              timestamp NOT NULL DEFAULT now()
);

COMMENT ON TABLE fw_task IS 'Tasks for the Business Oriented Framework';
COMMENT ON COLUMN fw_task.task_id IS 'Unique identification';
COMMENT ON COLUMN fw_task.user_id IS 'Reference to fw_user';
COMMENT ON COLUMN fw_task.transaction_id IS 'If several tasks need to be executed in sequence';
COMMENT ON COLUMN fw_task.function IS 'invoice, make docs, print docs, ...';
COMMENT ON COLUMN fw_task.parameters IS 'from client to the scheduled task';
COMMENT ON COLUMN fw_task.result IS 'result of the job';
COMMENT ON COLUMN fw_task.resulttype IS 'type of result; xml, html, etc';
COMMENT ON COLUMN fw_task.status IS '100 - entered, 140 - reserved for processing (transaction rows), 150 - processing started, 200 - processing finished, 900 - processing finished w/ error';
COMMENT ON COLUMN fw_task.updated IS 'Timestamp for latest update of this row';

CREATE TABLE fw_schedule (
       schedule_id          integer NOT NULL DEFAULT nextval('fw_schedulesequence')
                            PRIMARY KEY,
       title                text,
       schedtype            text,
       schedule             text,
       user_id              integer NOT NULL REFERENCES fw_user,
       function             text,
       parameters           text,
       result               text,
       resulttype           text,
       lastrun              timestamp,
       updated              timestamp NOT NULL DEFAULT now()
);

COMMENT ON TABLE fw_schedule IS 'Schedules for the Business Oriented Framework';
COMMENT ON COLUMN fw_schedule.schedule_id IS 'Unique identification';
COMMENT ON COLUMN fw_schedule.title IS 'Title of the schedule';
COMMENT ON COLUMN fw_schedule.schedtype IS 'The schedule type. Currently supported: "D" meaning daily at an exact time';
COMMENT ON COLUMN fw_schedule.schedule IS 'The schedule. "hh:mm"';
COMMENT ON COLUMN fw_schedule.user_id IS 'Reference to fw_user';
COMMENT ON COLUMN fw_schedule.function IS 'invoice, make docs, print docs, ...';
COMMENT ON COLUMN fw_schedule.parameters IS 'Params to the scheduled schedule';
COMMENT ON COLUMN fw_schedule.result IS 'Result of the job';
COMMENT ON COLUMN fw_schedule.resulttype IS 'Type of result; xml, html, etc';
COMMENT ON COLUMN fw_schedule.lastrun IS 'Timestamp for latest execution of schedule';
COMMENT ON COLUMN fw_schedule.updated IS 'Timestamp for latest update of this row';

-- Views

-- Functions

-- Triggers


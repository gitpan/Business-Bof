INSERT INTO fw_database (dbname, dbtype, dbusername, dbpassword, dbhost, dbschema) VALUES ('t/test.sqlite', 'SQLite', '', '', 'localhost', '');
INSERT INTO fw_database (dbname, dbtype, dbusername, dbpassword, dbhost, dbschema) VALUES ('bof', 'Pg', '', '', 'localhost', 'bof');

INSERT INTO fw_user (name, "password") VALUES ('bof', 'test');
INSERT INTO fw_user (name, "password") VALUES ('test', 'test');

INSERT INTO fw_usergroup (name, db_id, domainname) VALUES ('bof', 1, 'bof');
INSERT INTO fw_usergroup (name, db_id, domainname) VALUES ('Testers', 2, 'test');

INSERT INTO fw_useringroup (user_id, usergroup_id) VALUES (1, 1);
INSERT INTO fw_useringroup (user_id, usergroup_id) VALUES (2, 2);

INSERT INTO fw_menu (name, uri) VALUES ('Customer', 'updCustomer');
INSERT INTO fw_menu (name, uri) VALUES ('Update', 'updCustomer');
INSERT INTO fw_menu (name, uri) VALUES ('Customer Group', 'updCustgrp');
INSERT INTO fw_menu (name, uri) VALUES ('Order', 'updOrder');
INSERT INTO fw_menu (name, uri) VALUES ('Update', 'updOrder');
INSERT INTO fw_menu (name, uri) VALUES ('Invoice', 'invoice');
INSERT INTO fw_menu (name, uri) VALUES ('Loan', 'updLoan');
INSERT INTO fw_menu (name, uri) VALUES ('Chart of Account', 'updCoa');
INSERT INTO fw_menu (name, uri) VALUES ('Update Article', 'updArticle');
INSERT INTO fw_menu (name, uri) VALUES ('Update Batch', 'updGlbatch');
INSERT INTO fw_menu (name, uri) VALUES ('Transfer IC Orders', 'icOrders');
INSERT INTO fw_menu (name, uri) VALUES ('Invoice Batch', 'invBatch');
INSERT INTO fw_menu (name, uri) VALUES ('Accounts Receivables', 'updAr');
INSERT INTO fw_menu (name, uri) VALUES ('Tasks', 'task');
INSERT INTO fw_menu (name, uri) VALUES ('Choose Report', 'report');
INSERT INTO fw_menu (name, uri) VALUES ('Monthly Overview', 'loanMonthly');
INSERT INTO fw_menu (name, uri) VALUES ('Order history', 'orderHistory');
INSERT INTO fw_menu (name, uri) VALUES ('Printed Documents', 'docPrint');
INSERT INTO fw_menu (name, uri) VALUES ('General Ledger', NULL);
INSERT INTO fw_menu (name, uri) VALUES ('Accounts Receivables', NULL);
INSERT INTO fw_menu (name, uri) VALUES ('Product', NULL);
INSERT INTO fw_menu (name, uri) VALUES ('System', NULL);

INSERT INTO fw_menulink (parent_id, child_id) VALUES (1, 2);
INSERT INTO fw_menulink (parent_id, child_id) VALUES (1, 3);
INSERT INTO fw_menulink (parent_id, child_id) VALUES (4, 5);
INSERT INTO fw_menulink (parent_id, child_id) VALUES (4, 6);
INSERT INTO fw_menulink (parent_id, child_id) VALUES (7, 16);
INSERT INTO fw_menulink (parent_id, child_id) VALUES (4, 11);
INSERT INTO fw_menulink (parent_id, child_id) VALUES (4, 12);
INSERT INTO fw_menulink (parent_id, child_id) VALUES (1, 17);
INSERT INTO fw_menulink (parent_id, child_id) VALUES (19, 8);
INSERT INTO fw_menulink (parent_id, child_id) VALUES (19, 10);
INSERT INTO fw_menulink (parent_id, child_id) VALUES (19, 15);
INSERT INTO fw_menulink (parent_id, child_id) VALUES (20, 13);
INSERT INTO fw_menulink (parent_id, child_id) VALUES (21, 9);
INSERT INTO fw_menulink (parent_id, child_id) VALUES (22, 14);
INSERT INTO fw_menulink (parent_id, child_id) VALUES (22, 18);

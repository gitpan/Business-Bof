-- Database
INSERT INTO fw_database (dbname, dbusername, dbpassword, dbhost)
  VALUES ('fm', 'postgres', '', 'localhost');
-- User
INSERT INTO fw_user (name, password, contact_id)
  VALUES ('Freemoney', 'test');
-- User Group
INSERT INTO fw_usergroup (name, db_id, domainname)
  VALUES ('Administrators', currval('fw_dbsequence'), 'test');
INSERT INTO fw_useringroup (user_id, usergroup_id)
  VALUES (currval('fw_usersequence'), currval('fw_usergroupsequence'));
-- Menu
INSERT INTO fw_menu (name, uri) VALUES ('Customer', 'updCustomer.epl');
-- Update Customer
INSERT INTO fw_menulink (parent_id, child_id)
  VALUES (currval('fw_menusequence'), currval('fw_menusequence'));
INSERT INTO fw_menu (name, uri) VALUES ('Update', 'updCustomer.epl');
UPDATE fw_menulink SET child_id=currval('fw_menusequence')
  WHERE menulink_id = currval('fw_menulinksequence');
-- Update Customer Group
INSERT INTO fw_menu (name, uri) VALUES ('Customer Group', 'updCustgrp.epl');
INSERT INTO fw_menulink (parent_id, child_id)
  SELECT parent_id, currval('fw_menusequence') FROM fw_menulink
    WHERE menulink_id = currval('fw_menulinksequence');
--
INSERT INTO fw_menu (name, uri) VALUES ('Order', 'updOrder.epl');
-- Update Order
INSERT INTO fw_menulink (parent_id, child_id)
  VALUES (currval('fw_menusequence'), currval('fw_menusequence'));
INSERT INTO fw_menu (name, uri) VALUES ('Update', 'updOrder.epl');
UPDATE fw_menulink SET child_id=currval('fw_menusequence')
  WHERE menulink_id = currval('fw_menulinksequence');
-- Invoicing
INSERT INTO fw_menulink (parent_id, child_id)
  VALUES (currval('fw_menusequence'), currval('fw_menusequence'));
INSERT INTO fw_menu (name, uri) VALUES ('Invoice', 'invoice.epl');
UPDATE fw_menulink SET child_id=currval('fw_menusequence')
  WHERE menulink_id = currval('fw_menulinksequence');

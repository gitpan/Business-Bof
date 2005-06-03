package Business::Bof::Data::Fw;
  use base 'Class::DBI';

package Business::Bof::Data::Fw::fw_database;
  use constant PREFIX => "Business::Bof::Data::Fw";
  use base 'Business::Bof::Data::Fw';
  Business::Bof::Data::Fw::fw_database->table('fw_database');
  Business::Bof::Data::Fw::fw_database->columns(All => qw/
  	db_id
	dbtype
	dbname
	dbusername
	dbpassword
	dbhost
	updated
	dbschema
  /);
  Business::Bof::Data::Fw::fw_database->columns(Primary => 'db_id');
  Business::Bof::Data::Fw::fw_database->sequence('fw_dbsequence');
  Business::Bof::Data::Fw::fw_database->has_many('fw_usergroup_db_id', PREFIX.'::fw_usergroup' => 'db_id');

package Business::Bof::Data::Fw::fw_menu;
  use constant PREFIX => "Business::Bof::Data::Fw";
  use base 'Business::Bof::Data::Fw';
  Business::Bof::Data::Fw::fw_menu->table('fw_menu');
  Business::Bof::Data::Fw::fw_menu->columns(All => qw/
  	menu_id
	name
	uri
	updated
  /);
  Business::Bof::Data::Fw::fw_menu->columns(Primary => 'menu_id');
  Business::Bof::Data::Fw::fw_menu->sequence('fw_menusequence');
  Business::Bof::Data::Fw::fw_menu->has_many('fw_menulink_parent_id', PREFIX.'::fw_menulink' => 'menu_id');
  Business::Bof::Data::Fw::fw_menu->has_many('fw_menulink_child_id', PREFIX.'::fw_menulink' => 'menu_id');
  Business::Bof::Data::Fw::fw_menu->has_many('fw_usermenu_menu_id', PREFIX.'::fw_usermenu' => 'menu_id');

  Business::Bof::Data::Fw::fw_menu->add_constructor(topmenu => qq{
    menu_id NOT IN (SELECT child_id FROM fw_menulink)
    AND menu_id NOT IN
    (SELECT menu_id FROM fw_usermenu WHERE usergroup_id = ?)
  });
  Business::Bof::Data::Fw::fw_menu->set_sql(submenu => qq{
    SELECT __ESSENTIAL__
      FROM fw_menu JOIN fw_menulink
      ON (fw_menu.menu_id = fw_menulink.child_id)
      WHERE parent_id = ? AND fw_menu.menu_id NOT IN
      (SELECT menu_id FROM fw_usermenu WHERE usergroup_id = ?)
  });

package Business::Bof::Data::Fw::fw_menulink;
  use constant PREFIX => "Business::Bof::Data::Fw";
  use base 'Business::Bof::Data::Fw';
  Business::Bof::Data::Fw::fw_menulink->table('fw_menulink');
  Business::Bof::Data::Fw::fw_menulink->columns(All => qw/
  	menulink_id
	parent_id
	child_id
	updated
  /);
  Business::Bof::Data::Fw::fw_menulink->has_a(parent_id => PREFIX.'::fw_menu');
  Business::Bof::Data::Fw::fw_menulink->has_a(child_id => PREFIX.'::fw_menu');

package Business::Bof::Data::Fw::fw_schedule;
  use constant PREFIX => "Business::Bof::Data::Fw";
  use base 'Business::Bof::Data::Fw';
  Business::Bof::Data::Fw::fw_schedule->table('fw_schedule');
  Business::Bof::Data::Fw::fw_schedule->columns(All => qw/
  	schedule_id
	title
	schedtype
	schedule
	user_id
	function
	parameters
	result
	resulttype
	lastrun
	updated
  /);
  Business::Bof::Data::Fw::fw_schedule->columns(Primary => 'schedule_id');
  Business::Bof::Data::Fw::fw_schedule->sequence('fw_schedulesequence');
  Business::Bof::Data::Fw::fw_schedule->has_a(user_id => PREFIX.'::fw_user');

  Business::Bof::Data::Fw::fw_schedule->add_constructor(schedlist => qq{
    schedtype = ?
    AND ?::time >= schedule::time
    AND (lastrun IS null OR date_trunc(?, lastrun) < ?)
  });


package Business::Bof::Data::Fw::fw_task;
  use constant PREFIX => "Business::Bof::Data::Fw";
  use base 'Business::Bof::Data::Fw';
  Business::Bof::Data::Fw::fw_task->table('fw_task');
  Business::Bof::Data::Fw::fw_task->columns(All => qw/
  	task_id
	user_id
	transaction_id
	function
	title
	parameters
	result
	resulttype
	status
	updated
  /);
  Business::Bof::Data::Fw::fw_task->columns(Primary => 'task_id');
  Business::Bof::Data::Fw::fw_task->sequence('fw_tasksequence');
  Business::Bof::Data::Fw::fw_task->has_a(user_id => PREFIX.'::fw_user');

package Business::Bof::Data::Fw::fw_taskresult;
  use constant PREFIX => "Business::Bof::Data::Fw";
  use base 'Business::Bof::Data::Fw';
  Business::Bof::Data::Fw::fw_taskresult->table('fw_taskresult');
  Business::Bof::Data::Fw::fw_taskresult->columns(All => qw/
  	task_id
	updated
  /);

package Business::Bof::Data::Fw::fw_user;
  use constant PREFIX => "Business::Bof::Data::Fw";
  use base 'Business::Bof::Data::Fw';
  Business::Bof::Data::Fw::fw_user->table('fw_user');
  Business::Bof::Data::Fw::fw_user->columns(All => qw/
  	user_id
	name
	password
	updated
  /);
  Business::Bof::Data::Fw::fw_user->columns(Primary => 'user_id');
  Business::Bof::Data::Fw::fw_user->sequence('fw_usersequence');
  Business::Bof::Data::Fw::fw_user->has_many('fw_useringroup_user_id', PREFIX.'::fw_useringroup' => 'user_id');
  Business::Bof::Data::Fw::fw_user->has_many('fw_task_user_id', PREFIX.'::fw_task' => 'user_id');
  Business::Bof::Data::Fw::fw_user->has_many('fw_schedule_user_id', PREFIX.'::fw_schedule' => 'user_id');

package Business::Bof::Data::Fw::fw_usergroup;
  use constant PREFIX => "Business::Bof::Data::Fw";
  use base 'Business::Bof::Data::Fw';
  Business::Bof::Data::Fw::fw_usergroup->table('fw_usergroup');
  Business::Bof::Data::Fw::fw_usergroup->columns(All => qw/
  	usergroup_id
	name
	db_id
	domainname
	updated
  /);
  Business::Bof::Data::Fw::fw_usergroup->columns(Primary => 'usergroup_id');
  Business::Bof::Data::Fw::fw_usergroup->sequence('fw_usergroupsequence');
  Business::Bof::Data::Fw::fw_usergroup->has_a(db_id => PREFIX.'::fw_database');
  Business::Bof::Data::Fw::fw_usergroup->has_many('fw_usermenu_usergroup_id', PREFIX.'::fw_usermenu' => 'usergroup_id');
  Business::Bof::Data::Fw::fw_usergroup->has_many('fw_useringroup_usergroup_id', PREFIX.'::fw_useringroup' => 'usergroup_id');

package Business::Bof::Data::Fw::fw_useringroup;
  use constant PREFIX => "Business::Bof::Data::Fw";
  use base 'Business::Bof::Data::Fw';
  Business::Bof::Data::Fw::fw_useringroup->table('fw_useringroup');
  Business::Bof::Data::Fw::fw_useringroup->columns(All => qw/
  	user_id
	usergroup_id
	updated
  /);
  Business::Bof::Data::Fw::fw_useringroup->has_a(user_id => PREFIX.'::fw_user');
  Business::Bof::Data::Fw::fw_useringroup->has_a(usergroup_id => PREFIX.'::fw_usergroup');

package Business::Bof::Data::Fw::fw_usermenu;
  use constant PREFIX => "Business::Bof::Data::Fw";
  use base 'Business::Bof::Data::Fw';
  Business::Bof::Data::Fw::fw_usermenu->table('fw_usermenu');
  Business::Bof::Data::Fw::fw_usermenu->columns(All => qw/
  	usergroup_id
	menu_id
	updated
  /);
  Business::Bof::Data::Fw::fw_usermenu->has_a(menu_id => PREFIX.'::fw_menu');
  Business::Bof::Data::Fw::fw_usermenu->has_a(usergroup_id => PREFIX.'::fw_usergroup');

1;

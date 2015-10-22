CREATE TABLE moniteur_cases (
  id int(11) NOT NULL AUTO_INCREMENT,
  infraction_id int(11) NOT NULL,
  state varchar(300) DEFAULT NULL,
  action_completed varchar(300) NOT NULL,
  created_on datetime NOT NULL,
  updated_on datetime DEFAULT NULL,
  email_count int(11) DEFAULT NULL,
  outcome varchar(45) DEFAULT NULL,
  PRIMARY KEY (id)
);
CREATE TABLE moniteur_exemption_list (
  id int(11) NOT NULL,
  identifier varchar(300) NOT NULL,
  target int(11) NOT NULL,
  PRIMARY KEY (id)
);
CREATE TABLE moniteur_infraction_types (
  id int(11) NOT NULL,
  infraction_type varchar(300) DEFAULT NULL,
  tableau_site_id int(11) DEFAULT NULL,
  enabled varchar(300) DEFAULT NULL,
  search_query longtext,
  archive_email_template longtext,
  fixed_template longtext,
  enable_archive varchar(300) DEFAULT NULL,
  email_count int(11) DEFAULT NULL,
  `interval` int(11) DEFAULT NULL,
  email_template longtext,
  resolved_email_template longtext,
  archive_notice_template longtext,
  description longtext,
  PRIMARY KEY (id)
);
CREATE TABLE moniteur_infractions (
  id int(11) NOT NULL AUTO_INCREMENT,
  infraction_type_id int(11) DEFAULT NULL,
  infraction_value varchar(200) DEFAULT NULL,
  date_added datetime DEFAULT NULL,
  user_friendly_name varchar(300) DEFAULT NULL,
  user_name varchar(300) DEFAULT NULL,
  user_id int(11) DEFAULT NULL,
  user_email varchar(200) DEFAULT NULL,
  object_id int(11) DEFAULT NULL,
  object_name varchar(1000) DEFAULT NULL,
  object_type varchar(200) DEFAULT NULL,
  luid varchar(300) DEFAULT NULL,
  object_url varchar(300) DEFAULT NULL,
  object_site_id int(11) DEFAULT NULL,
  object_project_id int(11) DEFAULT NULL,
  PRIMARY KEY (id)
);
CREATE TABLE moniteur_sent_emails (
  id int(11) NOT NULL AUTO_INCREMENT,
  recipient varchar(200) DEFAULT NULL,
  subject varchar(300) DEFAULT NULL,
  msg longtext,
  date_sent datetime DEFAULT NULL,
  PRIMARY KEY (id)
);
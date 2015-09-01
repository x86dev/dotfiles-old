CREATE TABLE "plugin_mobilize_feeds" ( "id" int NOT NULL, "owner_uid" int NOT NULL, "mobilizer_id" int NOT NULL, PRIMARY KEY ("id","owner_uid") );
CREATE TABLE "plugin_mobilize_mobilizers" ( "id" int NOT NULL, "description" varchar(255) NOT NULL, "url" varchar(1000) NOT NULL, PRIMARY KEY ("id") ) ;

INSERT INTO "plugin_mobilize_mobilizers" ( "id", "description", "url") VALUES
(0, 'Readability', 'http://www.readability.com/m?url=%s'),
(1, 'Instapaper', 'http://www.instapaper.com/m?u=%s'),
(2, 'Google Mobilizer', 'http://www.google.com/gwt/x?u=%s'),
(3, 'Original Stripped', 'http://strip=%s'),
(4, 'Original', '%s');

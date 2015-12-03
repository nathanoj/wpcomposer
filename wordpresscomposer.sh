#!/bin/bash
# This script was created by jhaun@handbrewed.com for automating WordPress installs
if [[ $USER = "yourusername" ]]; then
        read -p "Enter the project name (all lower case, alphanumeric, no spaces, 16 characters or less): " project
        if [[ $project =~ [^a-zA-Z0-9] ]]; then
                echo "The project name you enetered is not valid."
                exit 2
        fi

        LEN=$(echo ${#project})
        if [ $LEN -gt 16 ]; then
                echo "Uh oh! The name $project has more than 16 characters. Try again!"
                exit 2
        fi

        read -p "Which version of WordPress? (please use the most current stable version): " wpversion

        read -p "What is the WordPress table prefix? (letters only. use 'wp' if you don't know): " wptableprefix
        if [[ $wptableprefix =~ [^a-zA-Z] ]]; then
                echo "The table prefix you enetered is not valid."
                exit 2
        fi

        dbpass=$(cat /dev/urandom | tr -dc 'a-zA-Z0-9' | fold -w 32 | head -n 1)
        current_time=$(date "+%Y-%m-%d %H:%M:%S")

        mkdir /var/www/devel/$USER/$project
        mkdir /var/www/devel/$USER/$project/html
        mkdir /var/www/devel/$USER/$project/resources

        localDir=/var/www/devel/$USER/$project

        cd /var/www/devel/$USER/$project

        cat <<JSON > $localDir/composer.json
        {
    "repositories": [
        {
            "type":"composer",
            "url":"http://wpackagist.org"
        },
        {
            "type": "package",
            "package": {
                "name": "wordpress",
                "type": "webroot",
                "version": "$wpversion",
                "dist": {
                    "type": "zip",
                    "url": "https://github.com/WordPress/WordPress/archive/$wpversion.zip"
                },
                "require" : {
                    "fancyguy/webroot-installer": "1.0.0"
                }
            }
        }
    ],
    "require": {
        "wpackagist-plugin/better-wp-security":">=4.8.0",
        "wordpress": "4.*",
        "fancyguy/webroot-installer": "1.0.0"
    },
    "extra": {
        "webroot-dir": "html/wp",
        "webroot-package": "wordpress",
        "installer-paths": {
            "html/wp-content/plugins/{\$name}/": ["type:wordpress-plugin"]
        }
    },
    "autoload": {
        "psr-0": {
            "HBDev": "src/"
        }
    }
}
JSON

        composer install
#       php composer.phar install
        cp -R html/wp/{wp-content,index.php} html/
        rm html/wp/wp-config-sample.php
        rm -rf html/wp-content/themes/twentyt* html/wp-content/themes/twentyeleven html/wp-content/themes/twentyfourteen
        rm html/wp-content/plugins/hello.php
        mkdir html/wp-content/uploads
        chmod 777 html/wp-content/uploads

        perl -pi -e 's/wp-blog-header.php/wp\/wp-blog-header.php/g' /var/www/devel/$USER/$project/html/index.php

        echo "Creating .htaccess file"
        cat <<HTACCESS > $localDir/html/.htaccess
<IfModule mod_rewrite.c>
RewriteEngine On
RewriteBase /
RewriteRule ^index\.php$ - [L]
RewriteCond %{REQUEST_FILENAME} !-f
RewriteCond %{REQUEST_FILENAME} !-d
RewriteRule . /index.php [L]
</IfModule>
HTACCESS

        echo "Creating database"
        params="mysql -uroot -p";
        mysql $params <<DELIMITER
        CREATE DATABASE IF NOT EXISTS $project;
DELIMITER

        echo "Creating database user and assigning grant permissions"
        mysql $params <<DELIMITER
        GRANT CREATE, SELECT, INSERT, UPDATE, DELETE ON $project.*
        TO '$project'@'localhost' IDENTIFIED BY '$dbpass';
DELIMITER

        echo "Creating wp-config.php"
        authKey=$(cat /dev/urandom | tr -dc 'a-zA-Z0-9' | fold -w 64 | head -n 1)
        secureAuthKey=$(cat /dev/urandom | tr -dc 'a-zA-Z0-9' | fold -w 64 | head -n 1)
        loggedInKey=$(cat /dev/urandom | tr -dc 'a-zA-Z0-9' | fold -w 64 | head -n 1)
        nonceKey=$(cat /dev/urandom | tr -dc 'a-zA-Z0-9' | fold -w 64 | head -n 1)
        authSalt=$(cat /dev/urandom | tr -dc 'a-zA-Z0-9' | fold -w 64 | head -n 1)
        secureAuthSalt=$(cat /dev/urandom | tr -dc 'a-zA-Z0-9' | fold -w 64 | head -n 1)
        loggedInSalt=$(cat /dev/urandom | tr -dc 'a-zA-Z0-9' | fold -w 64 | head -n 1)
        nonceSalt=$(cat /dev/urandom | tr -dc 'a-zA-Z0-9' | fold -w 64 | head -n 1)
        cat <<CONFIG > $localDir/html/wp-config.php
<?php
/**
 * Custom WordPress configurations on "wp-config.php" file.
 *
 * This file has the following configurations: MySQL settings, Table Prefix, Secret Keys, WordPress Language, ABSPATH and more.
 * For more information visit {@link http://codex.wordpress.org/Editing_wp-config.php Editing wp-config.php} Codex page.
 * Created using {@link http://generatewp.com/wp-config/ wp-config.php File Generator} on GenerateWP.com.
 *
 * @package WordPress
 * @generator GenerateWP.com
 */


/* MySQL settings */
define( 'DB_NAME',     '$project' );
define( 'DB_USER',     '$project' );
define( 'DB_PASSWORD', '$dbpass' );
define( 'DB_HOST',     'localhost' );
define( 'DB_CHARSET',  'utf8' );


/* MySQL database table prefix. */
\$table_prefix = '${wptableprefix}_';


/* Authentication Unique Keys and Salts. */
/* https://api.wordpress.org/secret-key/1.1/salt/ */
define( 'AUTH_KEY',         '$authKey' );
define( 'SECURE_AUTH_KEY',  '$secureAuthKey' );
define( 'LOGGED_IN_KEY',    '$loggedInKey' );
define( 'NONCE_KEY',        '$nonceKey' );
define( 'AUTH_SALT',        '$authSalt' );
define( 'SECURE_AUTH_SALT', '$secureAuthSalt' );
define( 'LOGGED_IN_SALT',   '$loggedInSalt' );
define( 'NONCE_SALT',       '$nonceSalt' );

define('WP_CONTENT_DIR', __DIR__ . '/wp-content');
define('WP_CONTENT_URL', 'http://' . \$_SERVER['SERVER_NAME'] . '/wp-content');
define('WP_SITEURL', 'http://' . \$_SERVER['SERVER_NAME'] . '/wp');
define('WP_HOME', 'http://' . \$_SERVER['SERVER_NAME']);

/* WordPress Localized Language. */
define( 'WPLANG', '' );


/* Absolute path to the WordPress directory. */
if ( !defined('ABSPATH') )
        define('ABSPATH', dirname(__FILE__) . '/');

/* Sets up WordPress vars and included files. */
require_once(ABSPATH . 'wp-settings.php');
CONFIG

        git init

        echo "Creating .gitignore file";
        cat <<GITIGNORE > $localDir/.gitignore
# -----------------------------------------------------------------
# .gitignore for Hand Brewed WordPress
# Hand Brewed Minimum Git
# http://www.handbrewed.com
# ver 20151203
#
# This file is tailored for a WordPress project
# using a CUSTOM directory structure
#
# This file specifies intentionally untracked files to ignore
# http://git-scm.com/docs/gitignore
#
# NOTES:
# The purpose of gitignore files is to ensure that certain files not
# tracked by Git remain untracked.
#
# To ignore uncommitted changes in a file that is already tracked,
# use `git update-index --assume-unchanged`.
#
# To stop tracking a file that is currently tracked,
# use `git rm --cached`
#
# Change Log:
#
# -----------------------------------------------------------------

html/wp-config.php
html/wp-content/themes/twenty*/
html/wp-content/plugins
html/wp-content/uploads
html/wp
vendor
resources

# track .editorconfig file (i.e. do NOT ignore it)
!.editorconfig

# track readme.md in the root (i.e. do NOT ignore it)
!readme.md

# ignore all files that start with ~
~*

# ignore OS generated files
ehthumbs.db
Thumbs.db

# ignore Editor files
*.sublime-project
*.sublime-workspace
*.komodoproject

# ignore log files and databases
*.log
*.sql
*.sqlite

# ignore compiled files
*.com
*.class
*.dll
*.exe
*.o
*.so

# ignore packaged files
*.7z
*.dmg
*.gz
*.iso
*.jar
*.rar
*.tar
*.zip
GITIGNORE

        git add .gitignore
        git add composer.json
        git add composer.lock
        git add html/.htaccess
        git add html/index.php
        git add html/wp-content
        git commit -m 'Initial commit'

        username=`git config github.user`
        if [ "$username" = "" ]; then
                echo "Could not find username, run 'git config --global github.user <username>'"
                invalid_credentials=1
        fi

        token=`git config github.token`
        if [ "$token" = "" ]; then
                echo "Could not find token, run 'git config --global github.token <token>'"
                invalid_credentials=1
        fi

        if [ "$invalid_credentials" == "1" ]; then
                exit 2
        fi

        echo "Creating Github repository '$project'"
        curl -u "$username:$token" https://api.github.com/user/repos -d '{"name":"'$project'","private":"'true'"}' > /dev/null 2>&1
        #curl -u "$username:$token" https://api.github.com/orgs/$theorg/repos -d '{"name":"'$project'","private":"'true'"}' > /dev/null 2>&1

        echo "Pushing local code to remote"
        #git remote add origin git@github.com:$theorg/$project.git
        git remote add origin git@github.com:$username/$project.git
        git push origin master

else
        echo "Something went wrong! It looks like you do not have permissions to do this!"
        exit 2
fi

# settings.py
# =================================================
# This script is for defining global parameters,
# such as database connection parameters.
#
# =================================================


# -----------------
# TABLEAU_DB
# -----------------
# These are connection details for the actual Tableau
# PostgreSQL database from which infractions are identified.

TABLEAU_DB = {'dbname': 'workgroup',
              'user': '',
              'password': '',
              'host': '',
              'port': 8060}


# -----------------
# MONITEUR_DB
# -----------------
# These are connection details for the MySQL database
# where all moniteur data is stored.

MONITEUR_DB = {'NAME': '',
               'USER': '',
               'PASSWORD': '',
               'HOST': '',
               'PORT': ''}


# -----------------
# TABLEAU_API
# -----------------
# These are connection details for establishing
# a Tableau REST API connection.

TABLEAU_API = {'server': '',
               'user': '',
               'password': '',

               # Workbook archive directory
               'archive_dir': 'archive/dir/...'}


# -----------------
# TABLEAU_URLS
# -----------------
# URL prefixes for use in emails.

TABLEAU_URLS = {'workbook': 'http://',
                'datasource': 'http://'}


# -----------------
# SMTP
# -----------------
# SMTP parameters for sending emails
# via the warning system.

SMTP = {'server': '',
        'port': 25,
        'username': '',
        'pass': '',
        'sender': ''}

# -----------------
# EMAIL GREETINGS
# -----------------

GREETINGS = ['Howdy!',
             'Greetings!',
             'Hello!',
             'Hey there!',
             'Ahoy!',
             'Yo!',
             'Bienvinidos!',
             'Hi!']

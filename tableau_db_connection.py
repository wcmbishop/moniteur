# tableau_db_connection.py
# =================================================
# Establishes connections to the Tableau PostgreSQL
# database.
#
# Database parameters are defined in
# moniteur_settings.py.
#
# =================================================


# =================================================
# imports

import psycopg2
import psycopg2.extras
import moniteur_settings
import logging


# =================================================
# Error logging

logging.basicConfig(filename='moniteur.log', level=logging.DEBUG)


# =================================================
# TABLEAU CONNECTION DECORATOR
# -------------------------------------------------


def tableau_db(func):

    """
    Wrap a function in an idiomatic SQL transaction for interaction
    with the Tableau 'workgroup' database. The wrapped function
    should take a cursor as its first argument; other arguments will be
    preserved.

    """

    def new_func(*args, **kwargs):

        conn = psycopg2.connect(database=moniteur_settings.TABLEAU_DB["dbname"],
                                user=moniteur_settings.TABLEAU_DB["user"],
                                password=moniteur_settings.TABLEAU_DB["password"],
                                host=moniteur_settings.TABLEAU_DB["host"],
                                port=moniteur_settings.TABLEAU_DB["port"])

        # Define the cursor that will be passed to the wrapped functions.
        # The cursor used is the 'RealDictCursor', which returns lists
        # of dictionaries, each dictionary containing a row of data.
        cursor = conn.cursor(cursor_factory=psycopg2.extras.RealDictCursor)

        try:
            retval = func(cursor, *args, **kwargs)
        except:
            logging.info('Error connecting to the Tableau Postgres workgroup database.')
            raise
        finally:
            cursor.close()

        return retval

    # Tidy up the help()-visible docstrings to be nice
    new_func.__name__ = func.__name__
    new_func.__doc__ = func.__doc__

    return new_func


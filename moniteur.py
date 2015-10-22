# moniteur.py
# =================================================
# This script contains the main functions that
# are executed during a moniteur run.
#
# =================================================


# =================================================
# imports
import os
import core_functions as core
from datetime import datetime, timedelta
import sys
import logging


# django imports
os.environ["DJANGO_SETTINGS_MODULE"] = "moniteur.settings"
from schema.models import InfractionType, Infraction, Case
import django
django.setup()
from django.db.models import Q
from django.template import Context, Template
from django.core.management import execute_from_command_line
from django.db import connection

# =================================================
# LOGGING
# -------------------------------------------------

logging.basicConfig(filename='moniteur.log', level=logging.DEBUG)


# =================================================
# INFRACTION TASKS
# -------------------------------------------------

def create_infraction_dicts():

    """
    Create infraction dictionaries.

    Returns
    -------
    infraction_dicts : list of dictionaries
        A list of dictionaries, each dictionary containing the fields
        required to insert an infraction in the 'moniteur_infractions'
        table.

    """

    # Get all (enabled) infractions.
    queried_infractions = core.query_infractions()

    infraction_dicts = []

    # Create infraction dicts for all queried infractions.
    for infraction in queried_infractions:
        infraction_dicts.append(core.create_infraction_dict(infraction))

    return infraction_dicts


# =================================================
# CASE TASKS
# -------------------------------------------------

def close_resolved_cases(session_infraction_id_list):

    """
    Close resolved cases. A case is 'resolved' when...

    Parameters
    ----------
    session_infraction_id_list : list
        A list of the ID's of all infractions that were logged in the
        current moniteur session.

    """

    # Get all open cases.
    open_cases = Case.objects.filter(~Q(state='closed')).select_related()

    # Check each case for a related infraction in current_infraction_id_list.
    for case in open_cases:

        # Get a count of infractions in the current session that have the same
        # infraction_type and object_id as the given open case.
        related_current_infraction = Infraction.objects.filter(id__in=session_infraction_id_list,
                                                               infraction_type_id=case.infraction.infraction_type_id,
                                                               object_id=case.infraction.object_id).count()

        # Set the state of the given case to 'closed' if no related current infraction exists.
        if related_current_infraction == 0:

            # Update case state
            case.state = 'closed'
            case.outcome = 'resolved'
            case.save()

            # Inform user via email that the case has been resolved.
            core.send_case_resolved_email(case)


def create_cases(infraction_id_list):

    """ Create cases for given infractions. """

    for infraction_id in infraction_id_list:
        core.create_case(infraction_id)


def update_case_states():

    """
    Update the state of all cases that are not closed, and with previous actions
    completed.

    """

    # Get cases that aren't closed, and whose previous action was completed.
    cases = Case.objects.filter(~Q(state='closed'), action_completed="True")

    # Update the state of each case.
    for case in cases:
        core.update_case_state(case)


# =================================================
# EMAIL ACTIONS
# -------------------------------------------------

def send_aggregate_emails():

    """
    Send aggregate emails. Each email, sent to a single user, contains information pertaining to one or
    more infractions of the same infraction type.

    """

    # Get a list of dictionaries of 'groups' of cases by user and infraction type - i.e distinct pairs of
    # users and infraction types.
    case_groups = Case.objects.filter(state='email',
                                      action_completed=False,
                                      infraction__infraction_type__enable_archive=False)\
                                      .values('infraction__user_name',
                                              'infraction__infraction_type_id',
                                              'infraction__infraction_type__infraction_type').distinct()

    # For each 'group', a single email is sent with aggregated infraction information.
    for group in case_groups:

        user_name = group['infraction__user_name']
        infraction_type_id = group['infraction__infraction_type_id']
        infraction_type_friendly = group['infraction__infraction_type__infraction_type']

        # Get all cases in current group.
        cases = Case.objects.filter(infraction__user_name=user_name,
                                    infraction__infraction_type_id=infraction_type_id,
                                    state='email',
                                    action_completed=False)

        # Get a list of the infraction ID's for all cases in the current group.
        case_infraction_ids = Case.objects.filter(infraction__user_name=user_name,
                                                  infraction__infraction_type_id=infraction_type_id,
                                                  state='email',
                                                  action_completed=False).values_list('infraction__id', flat=True)

        # Get a list of dictionaries containing data for all infractions in group.
        group_infractions = Infraction.objects.filter(id__in=case_infraction_ids).values()

        user_friendly_name = group_infractions[0]['user_friendly_name']
        user_email = group_infractions[0]['user_email']
        random_greeting = core.random_greeting()

        # Define the 'context' variables that will be used to render the email template.
        c = Context({'infractions': group_infractions,
                     'user_name': user_friendly_name,
                     'user_email': user_email,
                     'infraction_type_id': infraction_type_id,
                     'greeting': random_greeting})

        # Get the email template for the group infraction type.
        email_template = InfractionType.objects.get(id=infraction_type_id).email_template
        t = Template(email_template)

        # Render the template using the context defined above.
        email_msg = t.render(c)

        # Send email to the current user.
        core.send_email(recipient=user_email,
                        subject=infraction_type_friendly,
                        html_msg=email_msg)

        # Update case email_count and action_completed.
        for case in cases:
            case.action_completed = 'True'
            case.save()


def send_archive_warning_emails():

    """
    Send warning emails to inform users that their workbook is scheduled to be archived.
    """

    cases = Case.objects.filter(state='email',
                                action_completed=False,
                                infraction__infraction_type__enable_archive=True)

    for case in cases:

        # Define warning email variables for use in template.
        user_friendly_name = case.infraction.user_friendly_name
        user_email = case.infraction.user_email
        infraction_value = case.infraction.infraction_value
        email_count = case.infraction.infraction_type.email_count
        interval = case.infraction.infraction_type.interval
        archive_date = case.infraction.date_added + timedelta(days=(email_count + 1)*interval)
        random_greeting = core.random_greeting()
        object_name = case.infraction.object_name
        msg_subject = 'Workbook Archive Warning: %s' % object_name

        # Define template "context" - variables passed into the template for rendering.
        c = Context({'user_friendly_name': user_friendly_name,
                     'user_email': user_email,
                     'greeting': random_greeting,
                     'archive_date': archive_date.date(),
                     'object_name': object_name,
                     'infraction_value': infraction_value})

        # Get the email template for the group infraction type.
        email_template = InfractionType.objects.get(id=case.infraction.infraction_type.id).archive_email_template
        t = Template(email_template)

        # Render the template using the context defined above.
        email_msg = t.render(c)

        # Send email to the current user.
        core.send_email(recipient=user_email,
                        subject=msg_subject,
                        html_msg=email_msg)

    # Update case email_count and action_completed.
    for case in cases:
        case.action_completed = 'True'
        case.save()


# =================================================
# ARCHIVE ACTIONS
# -------------------------------------------------

def archive_workbooks():

    """ Archive all workbooks that are marked to be archived."""

    # Get all cases that are marked for archiving.
    cases = Case.objects.filter(state='archive',
                                action_completed=False)

    # Archive each case.
    for case in cases:
        core.archive_workbook(case)


# =================================================
# CASE ACTIONS
# -------------------------------------------------

def execute_case_actions():

    """ Execute actions based on case states. """

    # Send out aggregate emails.
    send_aggregate_emails()

    # Send out archive warning emails.
    send_archive_warning_emails()

    # Archive workbooks.
    archive_workbooks()


# =================================================
# RUN MONITEUR
# -------------------------------------------------

def run():

    """ Run a full moniteur session. """

    # Log start of moniteur run.
    logging.info('moniteur running. Start time: %s' % datetime.now())

    # Get a list of dictionaries, each dictionary containing data required to add the infraction
    # to the 'moniteur_infractions' table.
    infraction_dicts = create_infraction_dicts()

    # Create empty list for storing the ID's of all infractions logged in the current session.
    session_infraction_ids = []

    # Get the id of the last entered infraction in the previous moniteur run.
    last_infraction_id = core.latest_infraction_id()

    # Initialize a count of infractions entered in the current moniteur session.
    session_infraction_count = 0

    for infraction_dict in infraction_dicts:

        session_infraction_count += 1

        # Create infraction object using current infraction_dict.
        current_infraction = Infraction.objects.create(id=last_infraction_id + session_infraction_count,
                                                       infraction_type_id=infraction_dict['infraction_type'],
                                                       infraction_value=infraction_dict['infraction_value'],
                                                       date_added=datetime.now(),
                                                       user_friendly_name=infraction_dict['user_friendly_name'],
                                                       user_name=infraction_dict['user_name'],
                                                       user_id=infraction_dict['user_id'],
                                                       user_email=infraction_dict['user_email'],
                                                       object_id=infraction_dict['object_id'],
                                                       object_name=infraction_dict['object_name'],
                                                       object_type=infraction_dict['object_type'],
                                                       object_url=infraction_dict['object_url'],
                                                       luid=infraction_dict['luid'])

        # Add the id of the newly created infraction to current_session_ids.
        session_infraction_ids.append(last_infraction_id + session_infraction_count)

    # Close 'resolved' cases.
    close_resolved_cases(session_infraction_ids)

    # Create cases for all infractions in the current session.
    create_cases(session_infraction_ids)

    # Update case states.
    update_case_states()

    # Execute case actions based on their states.
    execute_case_actions()

    # Log end of moniteur run.
    logging.info('End time of moniteur run: %s' % datetime.now())


# =================================================
# DJANGO - EXECUTE FROM COMMAND LINE
# -------------------------------------------------
# These functions allow django command line
# functions to be called via moniteur.py, rather
# than the default manage.py.
# -------------------------------------------------

def runserver():
    """ Run local Django server """
    execute_from_command_line(['django', 'runserver'])


def loaddata():
    """ Insert initial moniteur data into database """
    execute_from_command_line(['django', 'loaddata', 'data/infraction_types.json'])


def makemigrations():
    """ Make Django model migrations """
    execute_from_command_line(['django', 'makemigrations'])


def migrate():
    """ Django migrate - will update moniteur db tables """
    execute_from_command_line(['django', 'migrate'])


def django(cmd):
    """ Use Django's execute_from_command_line 'django' calls """
    execute_from_command_line(['django', cmd])


def auth(cmd):
    """ Use Django's execute_from_command_line 'auth' calls """
    execute_from_command_line(['auth', cmd])


# =================================================
# EXECUTE FROM COMMAND LINE
# -------------------------------------------------

def createtables():

    # Get .sql file that containes CREATE statements.
    fd = open('data/create_tables.sql', 'r')
    sql = fd.read()

    # Create DB connection cursor.
    cursor = connection.cursor()

    # Execute the SQL to create database tables.
    cursor.execute(sql)


if __name__ == "__main__":

    # Take command line arguments. First argument calls a moniteur.py function,
    #  remaining arguments are passed to that function.
    globals()[sys.argv[1]](*sys.argv[2:])



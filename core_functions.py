# core_functions.py
# =================================================
# Contains the core moniteur functions. These
# functions are called from moniteur_tasks.py
# for use in moniteur's general task functions.
#
# =================================================


# =================================================
# imports

from tableau_db_connection import tableau_db
import os
import sys
import moniteur_settings as settings
import datetime
from datetime import timedelta
import random
from strudelpy import SMTP, Email
from tableau_rest_api.tableau_rest_api import *

# django imports
os.environ["DJANGO_SETTINGS_MODULE"] = "moniteur.settings"
import django
django.setup()

from schema.models import InfractionType, Infraction, Case, Exemption, SentEmail
from django.db.models import Q
from django.template import Context, Template
from django.core.exceptions import ObjectDoesNotExist

# =================================================
# QUERYING TABLEAU
# -------------------------------------------------


@tableau_db
def query_infractions_by_type(cursor, infraction_type_id):

    """
    Finds all infractions of the given type by running the associated infraction search
    query against the Tableau workgroup database. Returns a list of dictionaries, each
    dictionary containing a single row/infraction.

    Parameters
    ----------
    cursor : psycopg2 cursor
        Cursor passed to the function via the @tableau_db decorator.
    infraction_type_id : int
        The id of the infraction type to query.

    Returns
    -------
    infractions : list of dictionaries

    """

    query = InfractionType.objects.get(id=infraction_type_id).search_query

    # Execute SQL query that finds infractions.
    cursor.execute(query)
    infractions = cursor.fetchall()

    # Add the infraction_type_id to each infraction.
    for infraction in infractions:
        infraction['infraction_type'] = infraction_type_id

    return infractions


def query_infractions():

    """
    Query all infraction types that are enabled.

    Returns
    -------
    infractions : list of dictionaries

    """

    # Get a list of all enabled infraction types.
    infraction_types = InfractionType.objects.filter(enabled=True).values_list('id', flat=True)

    # Create empty list for storing queried infractions.
    infractions = []

    for infraction_type in infraction_types:
        infractions += query_infractions_by_type(infraction_type)

    return infractions


# =================================================
# PROCESS INFRACTIONS
# -------------------------------------------------


def create_infraction_dict(infraction):

    """
    Given a dictionary containing a row of data returned by an infraction search query,
    return a dictionary that contains all necesary fields to log the infraction
    in the 'moniteur_infractions' table.

    Parameters
    ----------
    infraction : dictionary
        A dictionary containing a single row of data return by an infraction
        search query.

    Returns
    -------
    infraction_dict : dictionary
        A dictionary that contains all fields needed to insert an
        infraction in the 'moniteur_infractions' table.

    """

    # Generate a URL for the object that can be used in warning emails.
    object_url = get_object_url(infraction)

    # Get all the columns/fields required to enter an infraction.
    # This is just an object containing all of the column names for the infractions table.
    infraction_fields = Infraction._meta.local_fields

    # Create a usable list from the object by pulling all the field names.
    infraction_field_names = [f.name for f in infraction_fields]

    # Create a dictionary of only required fields.
    infraction_dict = dict((k, v) for k, v in infraction.iteritems() if k in infraction_field_names)

    # Add object_url to infraction_dict.
    infraction_dict['object_url'] = object_url

    return infraction_dict


# =================================================
# CASE FUNCTIONS
# -------------------------------------------------

def create_case(infraction_id):

    """
    Given an infraction_id, insert a new case if there is no existing case
    associated with the given infraction's 'infraction_type' and 'object_id'.

    Parameters
    ----------
    infraction_id : int

    """

    # Create an infraction object for the given infraction_id.
    infraction = Infraction.objects.get(id=infraction_id)

    # If there is no existing case associated with the given infraction,
    # and no exemption, create case.

    if not case_exists(infraction) and not exemption_exists(infraction):

        Case.objects.create(infraction_id=infraction_id,
                            action_completed=False,
                            state="email",
                            created_on=infraction.date_added,
                            email_count=1)


def update_case_state(case):

    """
    Update date a given case state.

    Parameters
    ----------
    case : django object/instance

    """

    # Define required infraction_type variables for given case
    enable_archive = case.infraction.infraction_type.enable_archive
    type_email_count = case.infraction.infraction_type.email_count
    interval = case.infraction.infraction_type.interval

    # If case's infraction type has archiving enabled, and all warnings have been sent,
    # change state to 'archive'.

    # Only update cases whose previous action is "expired". This is determined by the infraction
    # type's 'interval' (# days) and the case's email count.
    if datetime.datetime.now() > case.created_on + datetime.timedelta(days=interval * case.email_count):

        # If enable_archive is true for given case, and all email warnings have been sent,
        # mark case object for archiving.
        if enable_archive == 'True' and case.email_count == type_email_count:

            case.state = 'archive'
            case.action_completed = 'False'
            case.save()

        elif enable_archive == 'False' and case.email_count == type_email_count:

            case.state = 'closed'
            case.save()

        # Increment email_count and set action_completed to 'False'.
        else:
            case.email_count += 1
            case.action_completed = 'False'
            case.save()


# =================================================
# EMAIL FUNCTIONS
# -------------------------------------------------


def send_email(recipient, subject, html_msg, logging_enabled=True):

    """
    Sends an HTML email to a given email address.

    Parameters
    ----------
    recipient : string
        Email address the email will be sent to.
    subject : string
        Email subject.
    html_msg : string
        The body of the email message. This may contain HTML tags.
    logging_enabled : boolean
        Boolean variable indicating whether or not emails should be logged.
        Logged emails are stored in the table 'moniteur_sent_emails'.

    """

    # Set SMTP parameters, which are defined globally in settings.py.
    smtpclient = SMTP(host=settings.SMTP["server"],
                      port=settings.SMTP["port"],
                      username=settings.SMTP["username"],
                      password=settings.SMTP["pass"],
                      ssl=False,
                      tls=False)

    # Send email.
    with smtpclient as smtp:
        smtp.send(Email(sender=settings.SMTP["sender"],
                        recipients=recipient, # row["user_email"]
                        subject=subject,
                        html=html_msg))

    # If email logging is enabled, insert email data into the 'moniteur_sent_emails' table.
    if logging_enabled:
        SentEmail.objects.create(recipient=recipient,
                                 subject=subject,
                                 msg=html_msg,
                                 date_sent=datetime.datetime.now())


def send_case_resolved_email(case):

    """
    Send an email to user informing them that the given case has been resolved.

    Parameters
    ----------
    case : django object/instance

    """

    user_friendly_name = case.infraction.user_friendly_name
    user_email = case.infraction.user_email
    infraction_type = case.infraction.infraction_type.infraction_type
    object_name = case.infraction.object_name
    msg_subject = 'Issue Resolved: %s' % object_name
    greeting = random_greeting()

    # Define the 'context' variables' that will be used to render the email template.
    c = Context({'user_friendly_name': user_friendly_name,
                 'infraction_type': infraction_type,
                 'object_name': object_name,
                 'greeting': greeting})

    # Get the email template for the group infraction type.
    email_template = case.infraction.infraction_type.resolved_email_template
    t = Template(email_template)

    # Render the template using the context defined above.
    email_msg = t.render(c)

    # Send email to the current user.
    send_email(recipient=user_email,
               subject=msg_subject,
               html_msg=email_msg)


def send_archive_notice_email(case):

    """
    Send an email to user informing them that their workbook is being archived.

    Parameters
    ----------
    case : django object/instance

    """

    user_friendly_name = case.infraction.user_friendly_name
    user_email = case.infraction.user_email
    infraction_type = case.infraction.infraction_type.infraction_type
    object_name = case.infraction.object_name
    msg_subject = 'Archive Notice: %s' % object_name
    greeting = random_greeting()

    # Define the 'context' variables' that will be used to render the email template.
    c = Context({'user_friendly_name': user_friendly_name,
                 'infraction_type': infraction_type,
                 'object_name': object_name,
                 'greeting': greeting})

    # Get the email template for the group infraction type.
    email_template = case.infraction.infraction_type.archive_notice_template
    t = Template(email_template)

    # Render the template using the context defined above.
    email_msg = t.render(c)

    # Send email to the current user.
    send_email(recipient=user_email,  # user_email
               subject=msg_subject,
               html_msg=email_msg)


def random_greeting():

    """ Return a random greeting from the GREETINGS list in moniteur_settings.py """

    greeting = random.choice(settings.GREETINGS)

    return greeting


# =================================================
# TABLEAU REST API CALLS
# -------------------------------------------------

def archive_workbook(case):

    """
    Archive workbook by luid. (IN PROGRESS)

    Parameters
    ----------
    case : django object/instance

    """

    try:

        # Establish API connection.
        tab_srv = TableauRestApi(settings.TABLEAU_API['server'],
                                 settings.TABLEAU_API['user'],
                                 settings.TABLEAU_API['password'],
                                 site_content_url='default')

        # Download workbook by LUID.
        tab_srv.download_workbook_by_luid(case.infraction.luid,
                                          filename="%s_%s" % (case.infraction.user_name, case.infraction.object_name))

        # Update case status.
        case.state = 'closed'
        case.outcome = 'archived'
        case.save()

        # Send email to user informing them their workbook is being archived.
        send_archive_notice_email(case)

    except urllib2.HTTPError, err:
        print err


# =================================================
# HELPER FUNCTIONS
# -------------------------------------------------

def get_object_url(infraction):

    """
    Generates an object's URL - for use in emails. Datasources and workbooks
    have different standard URL formats.

    Parameters
    ----------
    infraction : dictionary
        A dictionary containing a single row of data returned by an infraction
        search query.

    """

    if infraction['object_type'] == "Datasource":
        object_url = "%s/#/datasources?search=%s" % (settings.TABLEAU_SERVER, infraction['object_name'])
    elif infraction['object_type'] == "Workbook":
        object_url = "%s/#/workbooks/%s/views" % (settings.TABLEAU_SERVER, infraction['object_id'])
    else:
        object_url = None
    return object_url


def case_exists(infraction):

    """
    Take an infraction and determine if there is an existing, open case for that infraction.

    Parameters
    ----------
    infraction : django object/instance

    """

    # Check if the given infraction has an existing case.
    existing_case = Case.objects.filter(~Q(state='closed'),
                                        infraction__infraction_type_id=infraction.infraction_type.id,
                                        infraction__object_id=infraction.object_id).count()

    # If the existing case count is 0, return False.
    if existing_case == 0:
        return False
    # Else, return True.
    else:
        return True


def exemption_exists(infraction):

    """
    Return 'True' if given infraction object (datasource or workbook) has a related exemption.

    Parameters
    ----------
    infraction : django object/instance

    """

    # Convert infraction object to dictionary.
    infraction = infraction.__dict__

    # Get a list of dicts, each containing an exemption pair.
    exemptions = Exemption.objects.filter().values('identifier', 'target')

    exists = False

    for x in exemptions:

        if infraction[x['identifier']] == x['target']:
            exists = True

    return exists


def latest_infraction_id():

    """ Return the ID of the last entered/logged infraction. """

    # Get the id of the last entered infraction.
    try:
        infraction_id = Infraction.objects.latest('id').id

    # If no infractions exist (i.e 'moniteur_infractions' table is empty), create a dummy infraction, return its
    # ID, and then delete it. This prevents autoincrement errors.
    except ObjectDoesNotExist:

        infraction = Infraction.objects.create()
        infraction_id = Infraction.objects.latest('id').id
        infraction = Infraction.objects.get(id=infraction_id)
        infraction.delete()
        print infraction_id

    return infraction_id

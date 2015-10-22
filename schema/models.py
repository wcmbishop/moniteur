# models.py
# =================================================
# Each model defines a table...
#
# =================================================


# =================================================
# imports

from django.db import models


# =================================================
# INFRACTION TYPES
# -------------------------------------------------

class InfractionType(models.Model):

    """
    INFRACTION TYPE TABLE COLUMNS

    """

    id = models.IntegerField(default=0, primary_key=True)
    infraction_type = models.CharField(max_length=300)
    description = models.TextField(max_length=15000)
    tableau_site_id = models.IntegerField(default=0)
    enabled = models.CharField(max_length=300)
    search_query = models.TextField(max_length=15000, default="Enter query")

    # Email templates
    email_template = models.TextField(max_length=15000)
    resolved_email_template = models.TextField(max_length=15000)
    archive_email_template = models.TextField(max_length=15000)
    archive_notice_template = models.TextField(max_length=15000)

    enable_archive = models.CharField(max_length=300)
    email_count = models.IntegerField(default=0)
    interval = models.IntegerField(default=0)

    class Meta:
        db_table = 'moniteur_infraction_types'
        verbose_name = "Infraction Type"
        verbose_name_plural = "Infraction Types"
        managed = False


# =================================================
# INFRACTIONS
# -------------------------------------------------

class Infraction(models.Model):

    """
    INFRACTION TABLE COLUMNS

    """

    # Infraction information
    id = models.IntegerField(primary_key=True)
    infraction_type = models.ForeignKey(InfractionType, db_constraint=False)
    infraction_value = models.CharField(max_length=300)
    date_added = models.DateTimeField()

    # User information
    user_friendly_name = models.CharField(max_length=300, help_text="{{user_friendly_name}}")
    user_name = models.CharField(max_length=300, help_text="{{user_name}}")
    user_id = models.IntegerField(default=0)
    user_email = models.CharField(max_length=200, help_text="{{user_email}}")

    # Object information
    object_id = models.IntegerField(default=0)
    object_name = models.CharField(max_length=1000, help_text="{{object_name}}")
    object_type = models.CharField(max_length=200)
    luid = models.CharField(max_length=300)
    object_url = models.CharField(max_length=300)
    object_site_id = models.IntegerField(default=0)
    object_project_id = models.IntegerField(default=0)

    # The 'infraction_type' field connects each case to its related infraction
    # type = models.ForeignKey(InfractionTypes)

    class Meta:
        ordering = ["date_added"]
        verbose_name = "Logged Infraction"
        verbose_name_plural = "Logged Infractions"
        db_table = 'moniteur_infractions'
        managed = False

    def __str__(self):              # __unicode__ on Python 2
        return "Logged Infractions"


# =================================================
# CASES
# -------------------------------------------------


class Case(models.Model):

    """
    CASES TABLE COLUMNS

    """

    id = models.IntegerField(default=0, primary_key=True)
    infraction = models.ForeignKey(Infraction, db_constraint=False)
    state = models.CharField(max_length=300)
    action_completed = models.CharField(max_length=300)
    created_on = models.DateTimeField()
    updated_on = models.DateTimeField(null=True)
    email_count = models.IntegerField(default=0)
    outcome = models.CharField(max_length=45)

    class Meta:
        db_table = 'moniteur_cases'
        managed = False


# =================================================
# SENT EMAILS
# -------------------------------------------------


class SentEmail(models.Model):

    """
    SENT EMAILS TABLE COLUMNS

    """

    id = models.IntegerField(default=0, primary_key=True)
    recipient = models.CharField(max_length=300)
    subject = models.CharField(max_length=300)
    msg = models.TextField(max_length=15000)
    date_sent = models.DateTimeField()


    class Meta:
        db_table = 'moniteur_sent_emails'
        managed = False


# =================================================
# EXEMPTIONS
# -------------------------------------------------

class Exemption(models.Model):

    """
    EXEMPTIONS TABLE COLUMNS

    """

    id = models.IntegerField(default=0, primary_key=True)
    identifier = models.CharField(max_length=300)
    target = models.IntegerField()

    class Meta:
        db_table = 'moniteur_exemption_list'
        managed = False


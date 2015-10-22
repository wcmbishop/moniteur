from django.contrib import admin
from schema.models import Infraction, InfractionType, Case, Exemption


class InfractionTypesAdmin(admin.ModelAdmin):
    list_display = ('infraction_type', 'id', 'enabled', 'email_count', 'interval', 'enable_archive')


class InfractionsAdmin(admin.ModelAdmin):
    list_display = ('infraction_type_id', 'user_friendly_name')
    list_filter = ['infraction_type_id']


class CasesAdmin(admin.ModelAdmin):
    list_display = ('state', 'email_count')
    list_filter = ['state']


class ExemptionsAdmin(admin.ModelAdmin):
    list_display = ('identifier', 'target', 'id')
    list_filter = ['identifier']

admin.site.register(Infraction, InfractionsAdmin)
admin.site.register(InfractionType, InfractionTypesAdmin)
admin.site.register(Case, CasesAdmin)
admin.site.register(Exemption, ExemptionsAdmin)

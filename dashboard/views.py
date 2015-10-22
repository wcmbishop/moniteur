from django.shortcuts import render
from django.http import HttpResponse
from django.template import RequestContext, loader
from schema.models import InfractionType, Infraction, Case, Exemption, SentEmail


def index(request):

    infraction_types = InfractionType.objects.filter(enabled=False)

    template = loader.get_template('dashboard/index.html')

    context = RequestContext(request, {
        'infraction_types': infraction_types,
    })

    return HttpResponse(template.render(context))
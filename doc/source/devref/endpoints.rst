Endpoints
---------

The project's goal is to provide a consistent mechanism for endpoints.
OpenStack is a highly interconnected application, with various
components requiring connectivity details to numerous services,
including other OpenStack components and infrastructure elements such as
databases, queues, and memcached infrastructure. The project's goal is
to ensure that it can provide a consistent mechanism for defining these
"endpoints" across all charts and provide the macros necessary to
convert those definitions into usable endpoints. The charts should
consistently default to building endpoints that assume the operator is
leveraging all charts to build their OpenStack cloud. Endpoints should
be configurable if an operator would like a chart to work with their
existing infrastructure or run elements in different namespaces.

For instance, in the Neutron chart ``values.yaml`` the following
endpoints are defined:

::

    # typically overridden by environmental
    # values, but should include all endpoints
    # required by this chart
    endpoints:
      image:
        hosts:
          default: glance-api
        type: image
        path: null
        scheme: 'http'
        port:
          api: 9292
          registry: 9191
      compute:
        hosts:
          default: nova-api
        path: "/v2/%(tenant_id)s"
        type: compute
        scheme: 'http'
        port:
          api: 8774
          metadata: 8775
          novncproxy: 6080
      identity:
        hosts:
          default: keystone-api
        path: /v3
        type: identity
        scheme: 'http'
        port:
          admin: 35357
          public: 5000
      network:
        hosts:
          default: neutron-server
        path: null
        type: network
        scheme: 'http'
        port:
          api: 9696

These values define all the endpoints that the Neutron chart may need in
order to build full URL compatible endpoints to various services.
Long-term, these will also include database, memcached, and rabbitmq
elements in one place. Essentially, all external connectivity can be be
defined centrally.

The macros that help translate these into the actual URLs necessary are
defined in the ``helm-toolkit`` chart. For instance, the cinder chart
defines a ``glance_api_servers`` definition in the ``cinder.conf``
template:

::

    +glance_api_servers = {{ tuple "image" "internal" "api" . | include "helm-toolkit.endpoint_type_lookup_addr" }}

As an example, this line uses the ``endpoint_type_lookup_addr`` macro in
the ``helm-toolkit`` chart (since it is used by all charts). Note that
there is a second convention here. All ``{{ define }}`` macros in charts
should be pre-fixed with the chart that is defining them. This allows
developers to easily identify the source of a Helm macro and also avoid
namespace collisions. In the example above, the macro
``endpoint_type_look_addr`` is defined in the ``helm-toolkit`` chart.
This macro is passing three parameters (aided by the ``tuple`` method
built into the go/sprig templating library used by Helm):

-  image: This is the OpenStack service that the endpoint is being built
   for. This will be mapped to ``glance`` which is the image service for
   OpenStack.
-  internal: This is the OpenStack endpoint type we are looking for -
   valid values would be ``internal``, ``admin``, and ``public``
-  api: This is the port to map to for the service. Some components,
   such as glance, provide an ``api`` port and a ``registry`` port, for
   example.

Charts should not use hard coded values such as
``http://keystone-api:5000`` because these are not compatible with
operator overrides and do not support spreading components out over
various namespaces.

By default, each endpoint is located in the same namespace as the current
service's helm chart. To connect to a service which is running in a different
Kubernetes namespace, a ``namespace`` can be provided to each individual
endpoint.

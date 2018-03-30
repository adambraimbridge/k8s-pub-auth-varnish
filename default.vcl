vcl 4.0;

import basicauth;

backend health_check_service {
  .host = "upp-aggregate-healthcheck";
  .port = "8080";
}

backend default {
  .host = "path-routing-varnish";
  .port = "80";
}

backend dex {
    .host = "content-auth-dex";
    .port = "8080";
}

backend dex_redirect {
    .host = "content-auth-dex-redirect";
    .port = "8080";
}

acl purge {
    "localhost";
}

sub exploit_workaround_4_1 {
    # This needs to come before your vcl_recv function
    # The following code is only valid for Varnish Cache and
    # Varnish Cache Plus versions 4.1.x and 5.0.0
    if (req.http.transfer-encoding ~ "(?i)chunked") {
        C{
        struct dummy_req {
            unsigned magic;
            int step;
            int req_body_status;
        };
        ((struct dummy_req *)ctx->req)->req_body_status = 5;
        }C

        return (synth(503, "Bad request"));
    }
}

sub vcl_recv {
    call exploit_workaround_4_1;

    # allow PURGE from localhost
    if (req.method == "PURGE") {
        if (!client.ip ~ purge) {
            return(synth(405,"Not allowed."));
        }
        return (purge);
    }

    if (req.url ~ "^\/robots\.txt$") {
        return(synth(200, "robots"));
    }

    //  allow dex & dex-redirect access without requiring auth
    if (req.http.Host ~ "^.*-dex\.ft\.com$") {
        set req.backend_hint = dex;
        return (pass);
    }

    if (req.http.Host ~ "^.*-dex-redirect\.ft\.com$") {
        set req.backend_hint = dex_redirect;
        return (pass);
    }

    if ((req.url ~ "^\/__health.*$") || (req.url ~ "^\/__gtg.*$")) { 
        if ((req.url ~ "^\/__health\/(dis|en)able-category.*$") || (req.url ~ "^\/__health\/.*-ack.*$")) {
            if (!basicauth.match("/etc/varnish/auth/.htpasswd",  req.http.Authorization)) {
                return(synth(401, "Authentication required"));
            }
        }
        set req.backend_hint = health_check_service;
        return (pass);
    }

    if ("SL_API_KEY" != "" && req.url ~ "^\/__smartlogic-notifier\/notify.*apiKey=SL_API_KEY.*$") {
        return(pass);
    }

    if (!basicauth.match("/etc/varnish/auth/.htpasswd",  req.http.Authorization)) {
        return(synth(401, "Authentication required"));
    }

    unset req.http.Authorization;
    # We need authentication for internal apps, and no caching, and the authentication should not be passed to the internal apps.
    # This is why this line is after checking the authentication and unsetting the authentication header.
    if (req.url ~ "^\/__[\w-]*\/.*$") {
        set req.backend_hint = default;
        return (pipe);
    }
}

sub vcl_synth {
    if (resp.reason == "robots") {
        synthetic({"User-agent: *
Disallow: /"});
        return (deliver);
    }
    if (resp.status == 401) {
        set resp.http.WWW-Authenticate = "Basic realm=Secured";
        set resp.status = 401;
        return (deliver);
    }
}

sub vcl_backend_response {
    # Happens after we have read the response headers from the backend.
    #
    # Here you clean the response headers, removing silly Set-Cookie headers
    # and other mistakes your backend does.
    if (((beresp.status == 500) || (beresp.status == 502) || (beresp.status == 503) || (beresp.status == 504)) && (bereq.method == "GET" )) {
        if (bereq.retries < 2 ) {
            return(retry);
        }
    }
}

sub vcl_deliver {
    # Happens when we have all the pieces we need, and are about to send the
    # response to the client.
    #
    # You can do accounting or modifying the final object here.
    if (obj.hits > 0) {
        set resp.http.X-Cache = "HIT";
    } else {
        set resp.http.X-Cache = "MISS";
    }
}

vcl 4.0;

import vsthrottle;
import basicauth;
import std;
import saintmode;
import directors;


backend health_check_service {
  .host = "upp-aggregate-healthcheck";
  .port = "8080";
  .probe = {
      .url = "/__health";
      .timeout = 1s;
      .interval = 7s;
      .window = 5;
      .threshold = 2;
  }
}

backend health_check_service-second {
  .host = "upp-aggregate-healthcheck-second";
  .port = "8080";
  .probe = {
      .url = "/__health";
      .timeout = 1s;
      .interval = 7s;
      .window = 5;
      .threshold = 2;
  }
}

acl purge {
    "localhost";
}

sub vcl_init {
    # Instantiate sm1, sm2 for backends tile1, tile2
    # with 10 blacklisted objects as the threshold for marking the
    # whole backend sick.
    new health1 = saintmode.saintmode(health_check_service-second, 2);
    new health2 = saintmode.saintmode(health_check_service, 2);

    # Add both to a director. Use sm0, sm1 in place of tile1, tile2.
    # Other director types can be used in place of random.
    new healthdirector = directors.random();
    healthdirector.add_backend(health1.backend(), 1);
    healthdirector.add_backend(health2.backend(), 1);
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

    if ((req.url ~ "^\/__health.*$") || (req.url ~ "^\/__gtg.*$")) { 
        if ((req.url ~ "^\/__health\/(dis|en)able-category.*$") || (req.url ~ "^\/__health\/.*-ack.*$")) {
            if (!basicauth.match("/etc/varnish/auth/.htpasswd",  req.http.Authorization)) {
                return(synth(401, "Authentication required"));
            }
        }
        set req.backend_hint = healthdirector.backend();
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

sub vcl_backend_fetch {
    if ((bereq.backend == healthdirector.backend()) && (bereq.retries > 0)) {
        # Get a backend from the director.
        # When returning a backend, the director will only return backends
        # saintmode says are healthy.
        set bereq.backend = healthdirector.backend();
    }
}

sub vcl_backend_response {
    # Happens after we have read the response headers from the backend.
    #
    # Here you clean the response headers, removing silly Set-Cookie headers
    # and other mistakes your backend does.
    if (((beresp.status == 500) || (beresp.status == 502) || (beresp.status == 503) || (beresp.status == 504)) && (bereq.method == "GET" ) && ((beresp.backend.name != health_check_service) || (beresp.backend.name != health_check_service-second))) {
        if (bereq.retries < 2 ) {
            return(retry);
        }
    }
 
    if (((beresp.status == 500) || (beresp.status == 502) || (beresp.status == 503) || (beresp.status == 504)) && (bereq.method == "GET" ) && ((beresp.backend.name == health_check_service) || (beresp.backend.name == health_check_service-second))) {
        saintmode.blacklist(7s);
        return(retry);
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

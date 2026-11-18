package com.doggy.backend.global.ratelimit;

import org.apache.catalina.Valve;
import org.apache.catalina.valves.RemoteIpValve;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.boot.web.embedded.tomcat.TomcatServletWebServerFactory;
import org.springframework.boot.web.server.WebServerFactoryCustomizer;
import org.springframework.core.Ordered;
import org.springframework.core.annotation.Order;
import org.springframework.stereotype.Component;

/** Only explicitly configured reverse proxies may supply a client IP. */
@Component
@Order(Ordered.LOWEST_PRECEDENCE)
class TrustedProxyConfig implements WebServerFactoryCustomizer<TomcatServletWebServerFactory> {

    private final String trustedProxyIpRegex;

    TrustedProxyConfig(@Value("${doggy.trusted-proxy-ip-regex:${TRUSTED_PROXY_IP_REGEX:(?!)}}")
                       String trustedProxyIpRegex) {
        this.trustedProxyIpRegex = trustedProxyIpRegex;
    }

    @Override
    public void customize(TomcatServletWebServerFactory factory) {
        for (Valve valve : factory.getEngineValves()) {
            if (valve instanceof RemoteIpValve remoteIpValve) {
                remoteIpValve.setInternalProxies(trustedProxyIpRegex);
                remoteIpValve.setTrustedProxies("(?!)");
            }
        }
    }
}

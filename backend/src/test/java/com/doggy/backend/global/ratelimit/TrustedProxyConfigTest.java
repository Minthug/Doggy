package com.doggy.backend.global.ratelimit;

import org.apache.catalina.valves.RemoteIpValve;
import org.junit.jupiter.api.Test;
import org.springframework.boot.web.embedded.tomcat.TomcatServletWebServerFactory;

import static org.assertj.core.api.Assertions.assertThat;

class TrustedProxyConfigTest {

    @Test
    void disablesImplicitTrustInPrivateAndLoopbackAddresses() {
        RemoteIpValve valve = new RemoteIpValve();
        TomcatServletWebServerFactory factory = new TomcatServletWebServerFactory();
        factory.addEngineValves(valve);

        new TrustedProxyConfig("(?!)").customize(factory);

        assertThat(valve.getInternalProxies()).isEqualTo("(?!)");
        assertThat(valve.getTrustedProxies()).isEqualTo("(?!)");
    }

    @Test
    void onlyExplicitlyConfiguredProxyAddressesAreTrusted() {
        RemoteIpValve valve = new RemoteIpValve();
        TomcatServletWebServerFactory factory = new TomcatServletWebServerFactory();
        factory.addEngineValves(valve);

        new TrustedProxyConfig("192\\.0\\.2\\.10").customize(factory);

        assertThat(valve.getInternalProxies()).isEqualTo("192\\.0\\.2\\.10");
        assertThat(valve.getTrustedProxies()).isEqualTo("(?!)");
    }
}

package uy.edu.fing.geotravel.db;

import com.zaxxer.hikari.HikariConfig;
import com.zaxxer.hikari.HikariDataSource;

/**
 * Pool de conexiones único para toda la app. Cada módulo lo usa así:
 *
 *   try (Connection c = DataSourceProvider.get().getConnection()) { ... }
 *
 * Configuración por variables de entorno (ver infra/.env.example para los valores
 * que usa docker-compose; en Tomcat local, exportalas antes de arrancarlo o
 * seteá los defaults de abajo a los de tu ambiente):
 *
 *   DB_HOST     (default: localhost)
 *   DB_PORT     (default: 5432)
 *   DB_NAME     (default: geotravel)
 *   DB_USER     (default: geotravel)
 *   DB_PASSWORD (default: geotravel)
 */
public final class DataSourceProvider {

    private static final HikariDataSource INSTANCE = build();

    private DataSourceProvider() {
    }

    public static HikariDataSource get() {
        return INSTANCE;
    }

    private static HikariDataSource build() {
        String host = env("DB_HOST", "localhost");
        String port = env("DB_PORT", "5432");
        String name = env("DB_NAME", "geotravel");
        String user = env("DB_USER", "geotravel");
        String pass = env("DB_PASSWORD", "geotravel");

        HikariConfig config = new HikariConfig();
        config.setJdbcUrl("jdbc:postgresql://" + host + ":" + port + "/" + name);
        config.setUsername(user);
        config.setPassword(pass);
        config.setMaximumPoolSize(10);
        return new HikariDataSource(config);
    }

    private static String env(String key, String fallback) {
        String value = System.getenv(key);
        return (value == null || value.isEmpty()) ? fallback : value;
    }
}

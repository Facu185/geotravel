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
 *   DB_STATEMENT_TIMEOUT_MS (default: 15000) tiempo máximo de cada consulta; pasado ese tiempo PostgreSQL la
 *                           corta y devuelve error, así una consulta pesada no deja ocupadas las conexiones del
 *                           pool. 0 lo desactiva.
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
        // Explícito porque en Tomcat el driver dentro del .war no se autoregistra en DriverManager.
        config.setDriverClassName("org.postgresql.Driver");
        config.setJdbcUrl("jdbc:postgresql://" + host + ":" + port + "/" + name);
        config.setUsername(user);
        config.setPassword(pass);
        config.setMaximumPoolSize(10);
        // Parámetro de sesión de PostgreSQL: vale para todas las consultas de cada conexión del pool.
        config.addDataSourceProperty("options", "-c statement_timeout=" + env("DB_STATEMENT_TIMEOUT_MS", "15000"));
        return new HikariDataSource(config);
    }

    private static String env(String key, String fallback) {
        String value = System.getenv(key);
        return (value == null || value.isEmpty()) ? fallback : value;
    }
}

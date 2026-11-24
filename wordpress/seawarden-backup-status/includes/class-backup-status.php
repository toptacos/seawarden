<?php

if (!defined('ABSPATH')) {
    exit;
}

class SeaWarden_Backup_Status {
    private string $api_url;
    private string $env;

    public function __construct() {
        $this->env = $this->detect_env();
        $api = get_option('swbs_api_url', '');
        if ($api === '' && defined('SWBS_API')) {
            $api = SWBS_API;
        }
        $this->api_url = $api !== '' ? add_query_arg('env', $this->env, $api) : '';

        add_action('admin_menu', [$this, 'add_menu']);
        add_action('admin_init', [$this, 'register_settings']);
        add_action('wp_ajax_swbs_refresh', [$this, 'ajax_refresh']);
    }

    private function detect_env(): string {
        if (defined('SWBS_ENV')) {
            return preg_replace('/[^a-z]/', '', (string) SWBS_ENV) ?: 'production';
        }
        if (defined('WP_ENVIRONMENT_TYPE')) {
            $map = ['production' => 'production', 'staging' => 'staging', 'development' => 'development', 'local' => 'development'];
            $t = (string) WP_ENVIRONMENT_TYPE;
            return $map[$t] ?? 'production';
        }
        return 'production';
    }

    public function register_settings(): void {
        register_setting('swbs', 'swbs_api_url', [
            'type' => 'string',
            'sanitize_callback' => 'esc_url_raw',
            'default' => '',
        ]);
    }

    public function add_menu(): void {
        add_menu_page(
            'SeaWarden Backups',
            'SeaWarden',
            'manage_options',
            'seawarden-backup-status',
            [$this, 'render'],
            'dashicons-backup',
            30
        );
    }

    /** @return array<string,mixed>|null */
    private function fetch(): ?array {
        if ($this->api_url === '') {
            return null;
        }
        $response = wp_remote_get($this->api_url, [
            'timeout' => 15,
            'headers' => ['Accept' => 'application/json'],
        ]);
        if (is_wp_error($response)) {
            return null;
        }
        $code = (int) wp_remote_retrieve_response_code($response);
        if ($code !== 200) {
            return null;
        }
        $body = json_decode((string) wp_remote_retrieve_body($response), true);
        return is_array($body) ? $body : null;
    }

    public function ajax_refresh(): void {
        check_ajax_referer('swbs_refresh');
        if (!current_user_can('manage_options')) {
            wp_send_json_error(['message' => 'forbidden'], 403);
        }
        $data = $this->fetch();
        if ($data === null) {
            wp_send_json_error(['message' => 'unreachable'], 502);
        }
        wp_send_json_success($data);
    }

    public function render(): void {
        if (!current_user_can('manage_options')) {
            return;
        }
        $data = $this->fetch();
        ?>
        <div class="wrap">
            <h1><?php echo esc_html(get_admin_page_title()); ?> <small>v<?php echo esc_html(SWBS_VERSION); ?></small></h1>
            <form method="post" action="options.php" style="margin:1em 0;max-width:40rem">
                <?php settings_fields('swbs'); ?>
                <label for="swbs_api_url"><strong>Status API URL</strong></label>
                <input type="url" class="regular-text" id="swbs_api_url" name="swbs_api_url"
                       value="<?php echo esc_attr(get_option('swbs_api_url', '')); ?>"
                       placeholder="https://backups.example.com/api/backup-status.php" />
                <p class="description">Vault HTTPS endpoint only. Do not put SSH keys in WordPress.</p>
                <?php submit_button('Save'); ?>
            </form>
            <p>Environment: <code><?php echo esc_html($this->env); ?></code></p>
            <?php if ($data === null): ?>
                <div class="notice notice-error"><p>Cannot reach SeaWarden status API. Check the URL and vault TLS.</p></div>
            <?php else: ?>
                <table class="widefat striped" style="max-width:40rem">
                    <tbody>
                        <tr><th>Updated</th><td><?php echo esc_html((string) ($data['updated_at'] ?? '—')); ?></td></tr>
                        <tr><th>Last backup</th><td><?php echo esc_html((string) ($data['last_backup'] ?? '—')); ?></td></tr>
                        <tr><th>DB size (bytes)</th><td><?php echo esc_html((string) ($data['last_backup_size'] ?? '—')); ?></td></tr>
                        <tr><th>Files</th><td><?php echo esc_html((string) ($data['files_count'] ?? '—')); ?></td></tr>
                        <tr><th>Retention count</th><td><?php echo esc_html((string) ($data['total_backups'] ?? '—')); ?></td></tr>
                        <tr><th>Duration (s)</th><td><?php echo esc_html((string) ($data['duration_seconds'] ?? '—')); ?></td></tr>
                        <tr><th>OK</th><td><?php echo !empty($data['ok']) ? 'yes' : 'no'; ?></td></tr>
                    </tbody>
                </table>
            <?php endif; ?>
        </div>
        <?php
    }
}

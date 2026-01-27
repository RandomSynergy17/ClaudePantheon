<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>ClaudePantheon</title>
    <style>
        /* ═══════════════════════════════════════════════════════════
           Catppuccin Mocha Color Palette
           ═══════════════════════════════════════════════════════════ */
        :root {
            --ctp-rosewater: #f5e0dc;
            --ctp-flamingo: #f2cdcd;
            --ctp-pink: #f5c2e7;
            --ctp-mauve: #cba6f7;
            --ctp-red: #f38ba8;
            --ctp-maroon: #eba0ac;
            --ctp-peach: #fab387;
            --ctp-yellow: #f9e2af;
            --ctp-green: #a6e3a1;
            --ctp-teal: #94e2d5;
            --ctp-sky: #89dceb;
            --ctp-sapphire: #74c7ec;
            --ctp-blue: #89b4fa;
            --ctp-lavender: #b4befe;
            --ctp-text: #cdd6f4;
            --ctp-subtext1: #bac2de;
            --ctp-subtext0: #a6adc8;
            --ctp-overlay2: #9399b2;
            --ctp-overlay1: #7f849c;
            --ctp-overlay0: #6c7086;
            --ctp-surface2: #585b70;
            --ctp-surface1: #45475a;
            --ctp-surface0: #313244;
            --ctp-base: #1e1e2e;
            --ctp-mantle: #181825;
            --ctp-crust: #11111b;
        }

        /* ═══════════════════════════════════════════════════════════
           Base Styles
           ═══════════════════════════════════════════════════════════ */
        * {
            margin: 0;
            padding: 0;
            box-sizing: border-box;
        }

        body {
            font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, 'Helvetica Neue', Arial, sans-serif;
            background: linear-gradient(135deg, var(--ctp-crust) 0%, var(--ctp-base) 50%, var(--ctp-mantle) 100%);
            color: var(--ctp-text);
            min-height: 100vh;
            display: flex;
            flex-direction: column;
            align-items: center;
            padding: 2rem 1rem;
        }

        /* ═══════════════════════════════════════════════════════════
           Header / Logo Section
           ═══════════════════════════════════════════════════════════ */
        .header {
            text-align: center;
            margin-bottom: 3rem;
        }

        .logo {
            font-size: 5rem;
            margin-bottom: 1rem;
            animation: float 3s ease-in-out infinite;
        }

        @keyframes float {
            0%, 100% { transform: translateY(0); }
            50% { transform: translateY(-10px); }
        }

        .title {
            font-size: 2.5rem;
            font-weight: 700;
            color: var(--ctp-mauve);
            margin-bottom: 0.5rem;
            letter-spacing: 0.05em;
        }

        .subtitle {
            font-size: 1.1rem;
            color: var(--ctp-subtext0);
            font-weight: 400;
        }

        /* ═══════════════════════════════════════════════════════════
           Button Grid
           ═══════════════════════════════════════════════════════════ */
        .button-grid {
            display: flex;
            gap: 1.5rem;
            flex-wrap: wrap;
            justify-content: center;
            margin-bottom: 2rem;
            max-width: 800px;
        }

        .btn {
            display: flex;
            flex-direction: column;
            align-items: center;
            justify-content: center;
            padding: 1.5rem 2rem;
            min-width: 160px;
            border: 2px solid var(--ctp-surface2);
            border-radius: 16px;
            background: var(--ctp-surface0);
            color: var(--ctp-text);
            text-decoration: none;
            font-size: 1rem;
            font-weight: 500;
            cursor: pointer;
            transition: all 0.3s ease;
            box-shadow: 0 4px 12px rgba(0, 0, 0, 0.3);
        }

        .btn:hover {
            transform: translateY(-4px);
            box-shadow: 0 8px 24px rgba(0, 0, 0, 0.4);
        }

        .btn:active {
            transform: translateY(-2px);
        }

        .btn-icon {
            font-size: 2.5rem;
            margin-bottom: 0.75rem;
        }

        /* Button Variants */
        .btn-terminal {
            border-color: var(--ctp-mauve);
        }
        .btn-terminal:hover {
            background: var(--ctp-mauve);
            color: var(--ctp-crust);
        }

        .btn-files {
            border-color: var(--ctp-sapphire);
        }
        .btn-files:hover {
            background: var(--ctp-sapphire);
            color: var(--ctp-crust);
        }

        .btn-phpinfo {
            border-color: var(--ctp-peach);
        }
        .btn-phpinfo:hover {
            background: var(--ctp-peach);
            color: var(--ctp-crust);
        }
        .btn-phpinfo.active {
            background: var(--ctp-peach);
            color: var(--ctp-crust);
        }

        /* ═══════════════════════════════════════════════════════════
           PHP Info Accordion
           ═══════════════════════════════════════════════════════════ */
        .phpinfo-container {
            width: 100%;
            max-width: 1000px;
            margin-bottom: 2rem;
        }

        .phpinfo-accordion {
            max-height: 0;
            overflow: hidden;
            transition: max-height 0.5s ease-out;
            background: var(--ctp-surface0);
            border-radius: 16px;
            border: 2px solid var(--ctp-surface2);
        }

        .phpinfo-accordion.open {
            max-height: 600px;
            overflow-y: auto;
        }

        .phpinfo-content {
            padding: 1.5rem;
        }

        /* Style phpinfo() output */
        .phpinfo-content table {
            width: 100%;
            border-collapse: collapse;
            margin-bottom: 1rem;
        }

        .phpinfo-content td, .phpinfo-content th {
            padding: 0.5rem 0.75rem;
            text-align: left;
            border-bottom: 1px solid var(--ctp-surface2);
            font-size: 0.9rem;
        }

        .phpinfo-content th {
            background: var(--ctp-surface1);
            color: var(--ctp-mauve);
            font-weight: 600;
        }

        .phpinfo-content td.e {
            background: var(--ctp-surface1);
            color: var(--ctp-sapphire);
            width: 30%;
            font-weight: 500;
        }

        .phpinfo-content td.v {
            color: var(--ctp-text);
            word-break: break-word;
        }

        .phpinfo-content h1, .phpinfo-content h2 {
            color: var(--ctp-mauve);
            margin: 1rem 0 0.5rem 0;
            font-size: 1.25rem;
        }

        .phpinfo-content hr {
            border: none;
            border-top: 1px solid var(--ctp-surface2);
            margin: 1rem 0;
        }

        .phpinfo-content img {
            display: none;
        }

        .phpinfo-content a {
            color: var(--ctp-sapphire);
        }

        /* ═══════════════════════════════════════════════════════════
           Status Bar (Optional)
           ═══════════════════════════════════════════════════════════ */
        .status-bar {
            display: flex;
            gap: 2rem;
            flex-wrap: wrap;
            justify-content: center;
            margin-bottom: 2rem;
            padding: 1rem 1.5rem;
            background: var(--ctp-surface0);
            border-radius: 12px;
            border: 1px solid var(--ctp-surface2);
        }

        .status-item {
            display: flex;
            align-items: center;
            gap: 0.5rem;
            font-size: 0.9rem;
            color: var(--ctp-subtext1);
        }

        .status-dot {
            width: 8px;
            height: 8px;
            border-radius: 50%;
            background: var(--ctp-green);
        }

        .status-dot.warning {
            background: var(--ctp-yellow);
        }

        /* ═══════════════════════════════════════════════════════════
           Footer
           ═══════════════════════════════════════════════════════════ */
        .footer {
            margin-top: auto;
            text-align: center;
            padding-top: 2rem;
        }

        .footer-text {
            color: var(--ctp-overlay1);
            font-size: 0.9rem;
        }

        .footer-credit {
            color: var(--ctp-overlay0);
            font-size: 0.8rem;
            margin-top: 0.5rem;
        }

        /* ═══════════════════════════════════════════════════════════
           Mobile Responsive
           ═══════════════════════════════════════════════════════════ */
        @media (max-width: 600px) {
            .logo {
                font-size: 4rem;
            }

            .title {
                font-size: 1.8rem;
            }

            .subtitle {
                font-size: 1rem;
            }

            .button-grid {
                flex-direction: column;
                align-items: center;
            }

            .btn {
                width: 100%;
                max-width: 280px;
            }

            .status-bar {
                flex-direction: column;
                align-items: center;
                gap: 0.75rem;
            }

            .phpinfo-accordion.open {
                max-height: 400px;
            }
        }
    </style>
</head>
<body>

    <!-- Header -->
    <header class="header">
        <div class="logo">&#x1f3db;&#xfe0f;</div>
        <h1 class="title">ClaudePantheon</h1>
        <p class="subtitle">Persistent Claude Code Environment</p>
    </header>

    <!-- Navigation Buttons -->
    <nav class="button-grid">
        <a href="/terminal/" class="btn btn-terminal">
            <span class="btn-icon">&#x1f5a5;&#xfe0f;</span>
            <span>Terminal</span>
        </a>
        <a href="/files/" class="btn btn-files">
            <span class="btn-icon">&#x1f4c1;</span>
            <span>Files</span>
        </a>
        <button class="btn btn-phpinfo" onclick="togglePhpInfo()" id="phpinfo-btn">
            <span class="btn-icon">&#x1f527;</span>
            <span>PHP Info</span>
        </button>
    </nav>

    <!-- PHP Info Accordion -->
    <div class="phpinfo-container">
        <div class="phpinfo-accordion" id="phpinfo-accordion">
            <div class="phpinfo-content">
                <?php
                // Capture phpinfo output and strip headers
                ob_start();
                phpinfo(INFO_GENERAL | INFO_CONFIGURATION | INFO_MODULES | INFO_ENVIRONMENT);
                $phpinfo = ob_get_clean();

                // Extract body content only
                preg_match('/<body[^>]*>(.*?)<\/body>/is', $phpinfo, $matches);
                $content = isset($matches[1]) ? $matches[1] : $phpinfo;

                // Remove inline styles from tables for cleaner output
                $content = preg_replace('/style="[^"]*"/i', '', $content);

                echo $content;
                ?>
            </div>
        </div>
    </div>

    <!-- Status Bar -->
    <div class="status-bar">
        <div class="status-item">
            <span class="status-dot"></span>
            <span>PHP <?php echo phpversion(); ?></span>
        </div>
        <div class="status-item">
            <span class="status-dot"></span>
            <span><?php echo php_uname('s') . ' ' . php_uname('r'); ?></span>
        </div>
        <div class="status-item">
            <span class="status-dot"></span>
            <span>Server: <?php echo $_SERVER['SERVER_SOFTWARE'] ?? 'nginx'; ?></span>
        </div>
    </div>

    <!-- Footer -->
    <footer class="footer">
        <p class="footer-text">Access Claude Code from any device with a web browser</p>
        <p class="footer-credit">A RandomSynergy Production</p>
    </footer>

    <script>
        function togglePhpInfo() {
            const accordion = document.getElementById('phpinfo-accordion');
            const btn = document.getElementById('phpinfo-btn');

            accordion.classList.toggle('open');
            btn.classList.toggle('active');
        }
    </script>

</body>
</html>

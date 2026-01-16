---
layout: default
title: Download
permalink: /download/
description: Download Microverse - elegant system monitoring for macOS
---

<section class="hero" style="padding: 3rem 0;">
  <div class="wrapper">
    <h1>Download Microverse</h1>
    <p class="subtitle">Get started with elegant system monitoring</p>
  </div>
</section>

<section class="features">
  <div class="wrapper">
    <div class="download-section">
      <div class="download-card">
        <h2>Latest Release</h2>
        <p class="version" id="version-display">Loading version...</p>
        
        <div class="download-buttons">
          <a href="https://github.com/ashwch/microverse/releases/latest" class="btn btn-primary btn-large">
            <span class="download-icon">⬇</span>
            Download for macOS
          </a>
          <p class="download-info">macOS 13.0 or later • Apple Silicon & Intel</p>
        </div>

        <div class="download-stats">
          <div class="stat">
            <span class="stat-value">< 10 MB</span>
            <span class="stat-label">Download Size</span>
          </div>
          <div class="stat">
            <span class="stat-value">< 50 MB</span>
            <span class="stat-label">Memory Usage</span>
          </div>
          <div class="stat">
            <span class="stat-value">< 1%</span>
            <span class="stat-label">CPU Impact</span>
          </div>
        </div>
      </div>
    </div>

    <div class="installation-steps">
      <h2>Installation</h2>
      <ol>
        <li>
          <h3>Download the App</h3>
          <p>Click the download button above to get the latest version of Microverse.</p>
        </li>
        <li>
          <h3>Extract and Move</h3>
          <p>Double-click the downloaded ZIP file to extract it, then drag Microverse.app to your Applications folder.</p>
        </li>
        <li>
          <h3>Grant Permissions</h3>
          <p>On first launch, macOS will ask you to grant security permissions. Click "Open" when prompted.</p>
        </li>
        <li>
          <h3>Start Monitoring</h3>
          <p>Look for the alien icon (👽) in your menu bar. Click it to access all features!</p>
        </li>
      </ol>
    </div>

    <div class="security-note">
      <h2>🔒 Security & Privacy</h2>
      <div class="security-grid">
        <div class="security-item">
          <h3>macOS Permissions</h3>
          <p>Microverse may request permission to access system information. This is required for monitoring functionality and is used only locally on your device.</p>
        </div>
        <div class="security-item">
          <h3>Gatekeeper</h3>
          <p>If you see "Microverse can't be opened because it is from an unidentified developer", right-click the app and select "Open" to bypass Gatekeeper.</p>
        </div>
        <div class="security-item">
          <h3>No Data Collection</h3>
          <p>Microverse does not collect or sell personal data. System monitoring is local; optional features (updates + weather) make network requests to their providers.</p>
        </div>
        <div class="security-item">
          <h3>Open Source</h3>
          <p>The complete source code is available on <a href="https://github.com/ashwch/microverse">GitHub</a> for transparency and security auditing.</p>
        </div>
      </div>
    </div>

    <div class="other-options">
      <h2>Other Installation Methods</h2>
      
      <div class="install-option">
        <h3>Build from Source</h3>
        <p>For developers who want to build Microverse themselves:</p>
        <pre><code># Clone the repository
git clone https://github.com/ashwch/microverse.git
cd microverse

# Build with Xcode
xcodebuild -scheme Microverse -configuration Release

# Or open in Xcode
open Microverse.xcodeproj</code></pre>
      </div>

      <div class="install-option">
        <h3>Previous Versions</h3>
        <p>Need an older version? Browse all releases on the <a href="https://github.com/ashwch/microverse/releases">GitHub releases page</a>.</p>
      </div>
    </div>

    <div class="requirements">
      <h2>System Requirements</h2>
      <ul>
        <li>macOS 13.0 (Ventura) or later</li>
        <li>Apple Silicon (M1/M2/M3) or Intel processor</li>
        <li>10 MB free disk space</li>
        <li>No additional dependencies required</li>
      </ul>
    </div>
  </div>
</section>

<section class="hero" style="background: var(--background-color);">
  <div class="wrapper">
    <h2>Need Help?</h2>
    <p>Having trouble with installation or usage?</p>
    <div class="hero-buttons">
      <a href="https://github.com/ashwch/microverse/issues" class="btn btn-primary">Get Support</a>
      <a href="https://github.com/ashwch/microverse/tree/main/docs" class="btn btn-secondary">Read Documentation</a>
    </div>
  </div>
</section>

<style>
.download-section {
  max-width: 800px;
  margin: 0 auto 4rem;
}

.download-card {
  background: var(--background-alt);
  border-radius: 16px;
  padding: 3rem;
  text-align: center;
  border: 1px solid var(--border-color);
}

.version {
  font-size: 1.2rem;
  color: var(--text-light);
  margin-bottom: 2rem;
}

.download-buttons {
  margin: 2rem 0;
}

.btn-large {
  font-size: 1.2rem;
  padding: 1rem 3rem;
  display: inline-flex;
  align-items: center;
  gap: 0.5rem;
}

.download-icon {
  font-size: 1.5rem;
}

.download-info {
  margin-top: 1rem;
  color: var(--text-light);
  font-size: 0.9rem;
}

.download-stats {
  display: grid;
  grid-template-columns: repeat(3, 1fr);
  gap: 2rem;
  margin-top: 3rem;
  padding-top: 2rem;
  border-top: 1px solid var(--border-color);
}

.stat {
  text-align: center;
}

.stat-value {
  display: block;
  font-size: 2rem;
  font-weight: 700;
  color: var(--primary-color);
}

.stat-label {
  display: block;
  margin-top: 0.5rem;
  color: var(--text-light);
  font-size: 0.9rem;
}

.installation-steps {
  margin: 4rem 0;
}

.installation-steps ol {
  list-style: none;
  padding: 0;
  counter-reset: step-counter;
}

.installation-steps li {
  counter-increment: step-counter;
  position: relative;
  padding-left: 3rem;
  margin-bottom: 2rem;
}

.installation-steps li::before {
  content: counter(step-counter);
  position: absolute;
  left: 0;
  top: 0;
  width: 2rem;
  height: 2rem;
  background: var(--primary-color);
  color: white;
  border-radius: 50%;
  display: flex;
  align-items: center;
  justify-content: center;
  font-weight: 700;
}

.installation-steps h3 {
  margin-bottom: 0.5rem;
}

.security-note {
  background: var(--background-alt);
  border-radius: 12px;
  padding: 2rem;
  margin: 4rem 0;
  border: 1px solid var(--border-color);
}

.security-grid {
  display: grid;
  grid-template-columns: repeat(auto-fit, minmax(250px, 1fr));
  gap: 2rem;
  margin-top: 2rem;
}

.security-item h3 {
  font-size: 1.1rem;
  margin-bottom: 0.5rem;
}

.other-options {
  margin: 4rem 0;
}

.install-option {
  margin-bottom: 2rem;
}

.install-option pre {
  background: var(--code-bg);
  padding: 1rem;
  border-radius: 8px;
  overflow-x: auto;
  margin-top: 1rem;
}

.requirements {
  margin: 4rem 0;
}

.requirements ul {
  list-style: none;
  padding: 0;
}

.requirements li {
  padding: 0.5rem 0;
  padding-left: 1.5rem;
  position: relative;
}

.requirements li:before {
  content: "✓";
  position: absolute;
  left: 0;
  color: var(--secondary-color);
  font-weight: bold;
}

@media (max-width: 768px) {
  .download-stats {
    grid-template-columns: 1fr;
    gap: 1rem;
  }
  
  .btn-large {
    width: 100%;
    justify-content: center;
  }
}
</style>

<script>
// Fetch and display the latest version from GitHub
fetch('https://api.github.com/repos/ashwch/microverse/releases/latest')
  .then(response => response.json())
  .then(data => {
    const versionElement = document.getElementById('version-display');
    if (data && data.name) {
      // GitHub release names are like "Microverse 0.1.1"
      versionElement.textContent = data.name;
    } else if (data && data.tag_name) {
      // Fallback to tag name like "v0.1.1"
      versionElement.textContent = `Version ${data.tag_name.replace('v', '')}`;
    } else {
      versionElement.textContent = 'Latest Version';
    }
  })
  .catch(error => {
    console.error('Error fetching version:', error);
    document.getElementById('version-display').textContent = 'Latest Version';
  });
</script>

# ============================================================================
# PowerShell Search Engine Aggregator Script
# ============================================================================
# Purpose: Aggregates searches from multiple search engines with configurable
#          URL patterns and generates an HTML report with all search links
# Author: Disgorge with Claude AI
# Date: December 2025
# Version: 2.0
# ============================================================================

# ============================================================================
# SEARCH ENGINES CONFIGURATION
# ============================================================================
# Each search engine has:
#   - Name: Display name
#   - BaseURL: Base search URL
#   - QueryParam: The parameter name for search queries (e.g., "q", "search")
#   - CustomURL: (Optional) Full custom URL template using {query} placeholder
#   - Enabled: Whether to include this engine in searches

$SearchEngines = @(
    @{ Name = "Google"; BaseURL = "https://www.google.com/search"; QueryParam = "q"; Enabled = $true },
    @{ Name = "Microsoft Bing"; BaseURL = "https://www.bing.com/search"; QueryParam = "q"; Enabled = $true },
    @{ Name = "DuckDuckGo"; BaseURL = "https://duckduckgo.com/"; QueryParam = "q"; Enabled = $true },
    @{ Name = "Yahoo"; BaseURL = "https://search.yahoo.com/search"; QueryParam = "p"; Enabled = $true },
    @{ Name = "Brave Search"; BaseURL = "https://search.brave.com/search"; QueryParam = "q"; Enabled = $true },
    @{ Name = "Startpage"; BaseURL = "https://www.startpage.com/do/search"; QueryParam = "query"; Enabled = $true },
    @{ Name = "Qwant"; BaseURL = "https://www.qwant.com/"; QueryParam = "q"; Enabled = $true },
    @{ Name = "Ecosia"; BaseURL = "https://www.ecosia.org/search"; QueryParam = "q"; Enabled = $true },
    @{ Name = "Yandex"; BaseURL = "https://yandex.com/search/"; QueryParam = "text"; Enabled = $true },
    @{ Name = "Swisscows"; BaseURL = "https://swisscows.com/en/web"; QueryParam = "query"; Enabled = $true },
    
    # Meta Search Engines
    @{ Name = "Dogpile"; BaseURL = "https://www.dogpile.com/serp"; QueryParam = "q"; Enabled = $true },
    @{ Name = "Metacrawler"; BaseURL = "https://www.metacrawler.com/serp"; QueryParam = "q"; Enabled = $true },
    @{ Name = "WebCrawler"; BaseURL = "https://www.webcrawler.com/serp"; QueryParam = "q"; Enabled = $true },
    
    # Privacy-focused engines
    @{ Name = "SearXNG-1"; BaseURL = "https://searx.rhscz.eu/search"; QueryParam = "q"; Enabled = $true },
    @{ Name = "SearXNG-2"; BaseURL = "https://search.inetol.net/search"; QueryParam = "q"; Enabled = $true },
    @{ Name = "SearXNG-3"; BaseURL = "https://search.rhscz.eu/search"; QueryParam = "q"; Enabled = $true },
    
    # Specialized Search Engines
    @{ Name = "YouTube"; BaseURL = "https://www.youtube.com/results"; QueryParam = "search_query"; Enabled = $true },
    @{ Name = "Google Maps"; BaseURL = "https://www.google.com/maps/search/"; CustomURL = "https://www.google.com/maps/search/{query}"; Enabled = $true },
    @{ Name = "Google Shopping"; BaseURL = "https://www.google.com/search"; QueryParam = "q"; CustomURL = "https://www.google.com/search?tbm=shop&q={query}"; Enabled = $true },
    
    # Academic/Research
    @{ Name = "Semantic Scholar"; BaseURL = "https://www.semanticscholar.org/search"; QueryParam = "q"; Enabled = $true },
    @{ Name = "Internet Archive"; BaseURL = "https://archive.org/search"; QueryParam = "query"; Enabled = $true },
    @{ Name = "Library of Congress"; BaseURL = "https://www.loc.gov/search/"; QueryParam = "q"; Enabled = $true },
    
    # AI-Powered Search
    @{ Name = "Perplexity AI"; BaseURL = "https://www.perplexity.ai/search"; QueryParam = "q"; Enabled = $true },
    @{ Name = "Phind"; BaseURL = "https://www.phind.com/search"; QueryParam = "q"; Enabled = $true },
    @{ Name = "WolframAlpha"; BaseURL = "https://www.wolframalpha.com/input"; QueryParam = "i"; Enabled = $true },
    
    # International/Regional
    @{ Name = "Naver"; BaseURL = "https://search.naver.com/search.naver"; QueryParam = "query"; Enabled = $false },
    @{ Name = "Sogou"; BaseURL = "https://www.sogou.com/web"; QueryParam = "query"; Enabled = $false },
    @{ Name = "Youdao"; BaseURL = "https://www.youdao.com/w/eng/"; CustomURL = "https://www.youdao.com/w/eng/{query}"; Enabled = $false },
    @{ Name = "Daum"; BaseURL = "https://search.daum.net/search"; QueryParam = "q"; Enabled = $false },
    
    # Specialized/Niche
    @{ Name = "Shodan"; BaseURL = "https://www.shodan.io/search"; QueryParam = "query"; Enabled = $false },
    @{ Name = "TinEye"; BaseURL = "https://tineye.com/search"; QueryParam = "url"; Enabled = $false },
    @{ Name = "Ahmia (Tor)"; BaseURL = "https://ahmia.fi/search/"; QueryParam = "q"; Enabled = $false }
)

# ============================================================================
# CONFIGURATION OPTIONS
# ============================================================================

$Config = @{
    # Output settings
    OutputDirectory = "$PSScriptRoot\SearchResults"
    OpenInBrowser = $true
    
    # Display settings
    GroupByCategory = $false
    ShowTimestamp = $true
    ShowStatistics = $true
    
    # Behavior
    PromptForSearchTerms = $true
    DefaultSearchTerms = ""
    
    # Advanced
    IncludeDisabledEngines = $false  # Show disabled engines in output (grayed out)
    VerboseOutput = $true
}

# ============================================================================
# FUNCTIONS
# ============================================================================

function Get-URLEncoded {
    <#
    .SYNOPSIS
    URL encodes a string for use in query parameters
    #>
    param([string]$Text)
    return [System.Web.HttpUtility]::UrlEncode($Text)
}

function Build-SearchURL {
    <#
    .SYNOPSIS
    Constructs a search URL for a given engine and query
    #>
    param(
        [hashtable]$Engine,
        [string]$SearchQuery
    )
    
    $encodedQuery = Get-URLEncoded -Text $SearchQuery
    
    # Use custom URL template if provided
    if ($Engine.CustomURL) {
        return $Engine.CustomURL -replace '\{query\}', $encodedQuery
    }
    
    # Otherwise build standard URL
    $separator = if ($Engine.BaseURL -match '\?') { '&' } else { '?' }
    return "$($Engine.BaseURL)$separator$($Engine.QueryParam)=$encodedQuery"
}

function Get-SearchTerms {
    <#
    .SYNOPSIS
    Prompts user for search terms or uses default
    #>
    
    if ($Config.PromptForSearchTerms) {
        Write-Host ""
        Write-Host "Enter your search terms:" -ForegroundColor Cyan
        Write-Host "(Press Enter to use default or Ctrl+C to cancel)" -ForegroundColor Gray
        Write-Host ""
        
        $input = Read-Host "Search"
        
        if ([string]::IsNullOrWhiteSpace($input)) {
            if ([string]::IsNullOrWhiteSpace($Config.DefaultSearchTerms)) {
                Write-Host "No search terms provided. Exiting." -ForegroundColor Red
                exit
            }
            return $Config.DefaultSearchTerms
        }
        return $input.Trim()
    }
    
    return $Config.DefaultSearchTerms
}

function New-HTMLReport {
    <#
    .SYNOPSIS
    Generates an HTML report with all search engine links
    #>
    param(
        [array]$SearchResults,
        [string]$SearchQuery,
        [int]$TotalEngines,
        [int]$EnabledEngines
    )
    
    $timestamp = Get-Date -Format 'dddd, MMMM dd, yyyy - HH:mm:ss'
    $reportDate = Get-Date -Format 'yyyy-MM-dd at HH:mm:ss'
    
    # Start building HTML
    $html = @"
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Search Results - $([System.Web.HttpUtility]::HtmlEncode($SearchQuery))</title>
    <style>
        * {
            margin: 0;
            padding: 0;
            box-sizing: border-box;
        }
        
        body {
            font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, Oxygen, Ubuntu, Cantarell, sans-serif;
            background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
            min-height: 100vh;
            padding: 20px;
        }
        
        .container {
            max-width: 1200px;
            margin: 0 auto;
            background: white;
            border-radius: 20px;
            box-shadow: 0 20px 60px rgba(0, 0, 0, 0.3);
            overflow: hidden;
        }
        
        .header {
            background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
            color: white;
            padding: 40px;
            text-align: center;
        }
        
        .header h1 {
            font-size: 2.5em;
            margin-bottom: 10px;
            font-weight: 700;
        }
        
        .search-query {
            background: rgba(255, 255, 255, 0.2);
            padding: 15px 25px;
            border-radius: 50px;
            display: inline-block;
            margin-top: 15px;
            font-size: 1.2em;
            backdrop-filter: blur(10px);
        }
        
        .stats-bar {
            background: #f8f9fa;
            padding: 20px 40px;
            display: flex;
            justify-content: space-around;
            border-bottom: 2px solid #e9ecef;
        }
        
        .stat {
            text-align: center;
        }
        
        .stat-value {
            font-size: 2em;
            font-weight: bold;
            color: #667eea;
        }
        
        .stat-label {
            color: #6c757d;
            font-size: 0.9em;
            margin-top: 5px;
        }
        
        .content {
            padding: 40px;
        }
        
        .search-grid {
            display: grid;
            grid-template-columns: repeat(auto-fill, minmax(300px, 1fr));
            gap: 20px;
            margin-top: 20px;
        }
        
        .search-card {
            background: white;
            border: 2px solid #e9ecef;
            border-radius: 12px;
            padding: 20px;
            transition: all 0.3s ease;
            position: relative;
            overflow: hidden;
        }
        
        .search-card::before {
            content: '';
            position: absolute;
            top: 0;
            left: 0;
            right: 0;
            height: 4px;
            background: linear-gradient(90deg, #667eea, #764ba2);
            transform: scaleX(0);
            transition: transform 0.3s ease;
        }
        
        .search-card:hover {
            transform: translateY(-5px);
            box-shadow: 0 10px 30px rgba(102, 126, 234, 0.3);
            border-color: #667eea;
        }
        
        .search-card:hover::before {
            transform: scaleX(1);
        }
        
        .engine-name {
            font-size: 1.3em;
            font-weight: 600;
            color: #2c3e50;
            margin-bottom: 15px;
            display: flex;
            align-items: center;
            gap: 10px;
        }
        
        .engine-icon {
            width: 24px;
            height: 24px;
            background: linear-gradient(135deg, #667eea, #764ba2);
            border-radius: 6px;
            display: flex;
            align-items: center;
            justify-content: center;
            color: white;
            font-size: 0.7em;
        }
        
        .search-button {
            display: inline-block;
            background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
            color: white;
            padding: 12px 24px;
            text-decoration: none;
            border-radius: 8px;
            font-weight: 600;
            transition: all 0.3s ease;
            text-align: center;
        }
        
        .search-button:hover {
            transform: scale(1.05);
            box-shadow: 0 5px 15px rgba(102, 126, 234, 0.4);
        }
        
        .url-preview {
            font-size: 0.75em;
            color: #6c757d;
            margin-top: 10px;
            word-break: break-all;
            font-family: 'Courier New', monospace;
            background: #f8f9fa;
            padding: 8px;
            border-radius: 4px;
        }
        
        .footer {
            background: #f8f9fa;
            padding: 20px 40px;
            text-align: center;
            color: #6c757d;
            border-top: 2px solid #e9ecef;
        }
        
        .disabled-engine {
            opacity: 0.5;
            pointer-events: none;
        }
        
        @media (max-width: 768px) {
            .search-grid {
                grid-template-columns: 1fr;
            }
            
            .header h1 {
                font-size: 1.8em;
            }
            
            .stats-bar {
                flex-direction: column;
                gap: 15px;
            }
        }
        
        .quick-actions {
            margin: 20px 0;
            padding: 20px;
            background: #f8f9fa;
            border-radius: 12px;
            text-align: center;
        }
        
        .quick-action-btn {
            background: white;
            border: 2px solid #667eea;
            color: #667eea;
            padding: 10px 20px;
            margin: 5px;
            border-radius: 8px;
            cursor: pointer;
            font-weight: 600;
            transition: all 0.3s ease;
        }
        
        .quick-action-btn:hover {
            background: #667eea;
            color: white;
        }
    </style>
    <script>
        function openAll() {
            const links = document.querySelectorAll('.search-button:not(.disabled-engine .search-button)');
            links.forEach((link, index) => {
                setTimeout(() => {
                    window.open(link.href, '_blank');
                }, index * 100);
            });
        }
        
        function openSelected(category) {
            const links = document.querySelectorAll('.search-button:not(.disabled-engine .search-button)');
            const enabledLinks = Array.from(links);
            const count = Math.min(category === 'top5' ? 5 : 10, enabledLinks.length);
            
            for (let i = 0; i < count; i++) {
                setTimeout(() => {
                    window.open(enabledLinks[i].href, '_blank');
                }, i * 100);
            }
        }
    </script>
</head>
<body>
    <div class="container">
        <div class="header">
            <h1>🔍 Search Engine Aggregator</h1>
            <div class="search-query">
                "$([System.Web.HttpUtility]::HtmlEncode($SearchQuery))"
            </div>
        </div>
        
        <div class="stats-bar">
            <div class="stat">
                <div class="stat-value">$EnabledEngines</div>
                <div class="stat-label">Active Engines</div>
            </div>
            <div class="stat">
                <div class="stat-value">$TotalEngines</div>
                <div class="stat-label">Total Available</div>
            </div>
            <div class="stat">
                <div class="stat-value">$(Get-Date -Format 'HH:mm')</div>
                <div class="stat-label">Generated At</div>
            </div>
        </div>
        
        <div class="content">
            <div class="quick-actions">
                <strong>Quick Actions:</strong><br><br>
                <button class="quick-action-btn" onclick="openSelected('top5')">Open Top 5 🚀</button>
                <button class="quick-action-btn" onclick="openSelected('top10')">Open Top 10 ⚡</button>
                <button class="quick-action-btn" onclick="openAll()">Open All 🌐</button>
            </div>
            
            <div class="search-grid">
"@

    # Add each search result
    foreach ($result in $SearchResults) {
        $cardClass = if (-not $result.Enabled) { 'search-card disabled-engine' } else { 'search-card' }
        $icon = ($result.Name.Substring(0,1)).ToUpper()
        
        $html += @"
                <div class="$cardClass">
                    <div class="engine-name">
                        <div class="engine-icon">$icon</div>
                        $([System.Web.HttpUtility]::HtmlEncode($result.Name))
                    </div>
                    <a href="$([System.Web.HttpUtility]::HtmlAttributeEncode($result.URL))" target="_blank" class="search-button">
                        🔎 Search on $([System.Web.HttpUtility]::HtmlEncode($result.Name))
                    </a>
                    <div class="url-preview">$([System.Web.HttpUtility]::HtmlEncode($result.URL))</div>
                </div>
"@
    }

    # Close HTML
    $html += @"
            </div>
        </div>
        
        <div class="footer">
            <p><strong>Generated:</strong> $reportDate</p>
            <p style="margin-top: 10px; font-size: 0.9em;">
                🌟 Search Engine Aggregator v2.0 - Powered by PowerShell
            </p>
        </div>
    </div>
</body>
</html>
"@

    return $html
}

function Show-Banner {
    <#
    .SYNOPSIS
    Displays a welcome banner
    #>
    
    Write-Host ""
    Write-Host "╔════════════════════════════════════════════════════════════╗" -ForegroundColor Cyan
    Write-Host "║                                                            ║" -ForegroundColor Cyan
    Write-Host "║         🔍  SEARCH ENGINE AGGREGATOR v2.0  🔍              ║" -ForegroundColor Cyan
    Write-Host "║                                                            ║" -ForegroundColor Cyan
    Write-Host "╚════════════════════════════════════════════════════════════╝" -ForegroundColor Cyan
    Write-Host ""
}

function Show-Summary {
    <#
    .SYNOPSIS
    Displays a summary of the operation
    #>
    param(
        [string]$OutputPath,
        [int]$EnabledCount,
        [int]$TotalCount
    )
    
    Write-Host ""
    Write-Host "╔════════════════════════════════════════════════════════════╗" -ForegroundColor Green
    Write-Host "║                    ✅ SUCCESS                              ║" -ForegroundColor Green
    Write-Host "╚════════════════════════════════════════════════════════════╝" -ForegroundColor Green
    Write-Host ""
    Write-Host "  📊 Statistics:" -ForegroundColor Yellow
    Write-Host "     • Enabled Engines: $EnabledCount" -ForegroundColor White
    Write-Host "     • Total Engines: $TotalCount" -ForegroundColor White
    Write-Host ""
    Write-Host "  📁 Output Location:" -ForegroundColor Yellow
    Write-Host "     $OutputPath" -ForegroundColor White
    Write-Host ""
}

# ============================================================================
# MAIN SCRIPT EXECUTION
# ============================================================================

# Load required assemblies
Add-Type -AssemblyName System.Web

# Show banner
Show-Banner

# Get search terms
$searchQuery = Get-SearchTerms

if ([string]::IsNullOrWhiteSpace($searchQuery)) {
    Write-Host "❌ Error: No search terms provided" -ForegroundColor Red
    exit 1
}

Write-Host "🎯 Search Query: " -NoNewline -ForegroundColor Cyan
Write-Host "`"$searchQuery`"" -ForegroundColor White
Write-Host ""

# Create output directory
if (-not (Test-Path $Config.OutputDirectory)) {
    New-Item -ItemType Directory -Path $Config.OutputDirectory -Force | Out-Null
    Write-Host "✅ Created output directory: $($Config.OutputDirectory)" -ForegroundColor Green
    Write-Host ""
}

# Build search URLs
Write-Host "🔧 Building search URLs..." -ForegroundColor Cyan
Write-Host ""

$searchResults = @()
$enabledCount = 0

foreach ($engine in $SearchEngines) {
    try {
        $url = Build-SearchURL -Engine $engine -SearchQuery $searchQuery
        
        $searchResults += @{
            Name = $engine.Name
            URL = $url
            Enabled = $engine.Enabled
        }
        
        if ($engine.Enabled) {
            $enabledCount++
            if ($Config.VerboseOutput) {
                Write-Host "  ✓ $($engine.Name)" -ForegroundColor Green
            }
        } else {
            if ($Config.VerboseOutput) {
                Write-Host "  ○ $($engine.Name) (disabled)" -ForegroundColor Gray
            }
        }
    }
    catch {
        Write-Host "  ✗ $($engine.Name) - Error: $($_.Exception.Message)" -ForegroundColor Red
    }
}

Write-Host ""
Write-Host "📝 Generating HTML report..." -ForegroundColor Cyan

# Generate HTML report
$fileName = "SearchResults_$(Get-Date -Format 'yyyy-MM-dd_HHmmss').html"
$fullPath = Join-Path $Config.OutputDirectory $fileName

$htmlContent = New-HTMLReport -SearchResults $searchResults `
                                -SearchQuery $searchQuery `
                                -TotalEngines $SearchEngines.Count `
                                -EnabledEngines $enabledCount

$htmlContent | Out-File -FilePath $fullPath -Encoding UTF8

# Show summary
Show-Summary -OutputPath $fullPath -EnabledCount $enabledCount -TotalCount $SearchEngines.Count

# Open in browser
if ($Config.OpenInBrowser) {
    Write-Host "🌐 Opening in default browser..." -ForegroundColor Cyan
    Start-Process $fullPath
    Start-Sleep -Seconds 1
}

Write-Host "🎉 Script completed successfully!" -ForegroundColor Green
Write-Host ""
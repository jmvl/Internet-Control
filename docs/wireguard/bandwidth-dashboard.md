# WireGuard Bandwidth Dashboard

**Status**: ✅ Production Deployed
**Location**: `/wireguard-dashboard`
**Tech Stack**: Next.js 14 + shadcn/ui + Recharts
**Port**: 3001
**Live URL**: http://wg.accelior.com:3001
**Deployed**: 2025-10-10

## Overview

Modern, beautiful web dashboard for visualizing WireGuard VPN bandwidth usage with real-time charts and statistics. Fully deployed and operational on production WireGuard server.

## Features

- ✨ **Real-time Monitoring**: Auto-refreshes every minute
- 📊 **Interactive Charts**: Area charts for timeline, bar charts for client comparison
- 👥 **Per-Client Tracking**: See bandwidth usage by individual VPN clients
- 📱 **Responsive Design**: Works perfectly on desktop and mobile
- 🎨 **Modern UI**: Beautiful shadcn/ui components with Tailwind CSS
- 🌓 **Dark Mode Ready**: Full dark mode support

## Screenshots

### Dashboard Overview
- Clean header with WireGuard branding
- Three stat cards showing Total Download, Total Upload, and Total Bandwidth
- Tab navigation between Timeline and Client views

### Timeline View
- Area chart showing bandwidth usage over the last 24 hours
- Stacked areas for multiple clients
- Hourly granularity

### Client View
- Bar chart comparing download/upload per client
- Detailed table with exact numbers
- Total bandwidth calculation

## Development

### Local Development
```bash
cd /Users/jm/Codebase/internet-control/wireguard-dashboard

# Install dependencies
npm install

# Run development server
npm run dev

# Open browser
open http://localhost:3001
```

### Project Structure
```
wireguard-dashboard/
├── app/
│   ├── api/
│   │   └── bandwidth/
│   │       └── route.ts          # API endpoint for bandwidth data
│   ├── globals.css                # Tailwind + shadcn styles
│   ├── layout.tsx                 # Root layout
│   └── page.tsx                   # Main dashboard page
├── components/
│   └── ui/
│       ├── card.tsx               # shadcn Card component
│       └── tabs.tsx               # shadcn Tabs component
├── lib/
│   └── utils.ts                   # Utility functions (cn helper)
├── package.json
├── tailwind.config.ts
├── tsconfig.json
├── Dockerfile                     # Production Docker image
└── README.md
```

## API Integration

The dashboard reads bandwidth logs from the WireGuard server's logging system.

### Production Integration (Currently Deployed)
The API endpoint (`/api/bandwidth/route.ts`) reads real data from:
```
/var/log/wireguard/bandwidth-YYYY-MM.log
```

**Data Flow:**
1. WireGuard tracking script writes bandwidth logs hourly
2. Docker container mounts `/var/log/wireguard` as read-only volume
3. API endpoint parses CSV logs and filters by period (today/week/month)
4. Frontend fetches data every 60 seconds via REST API
5. Charts render with Recharts library

**Graceful Fallback:**
- If real logs are unavailable (development/permissions), falls back to mock data
- Ensures dashboard always displays something meaningful

### Log Format
The bandwidth logs use this CSV format:
```csv
unix_timestamp,datetime,public_key,client_name,rx_bytes,tx_bytes,rx_mb,tx_mb,total_mb
```

**Example Real Data:**
```csv
1759954165,2025-10-08 22:09:25,R49dHwwD10sShxVkpPeXPsP2Cu27lCFgoAbxFrj2YBQ=,JM MacBook Pro,23462368,353708940,22.38,337.32,359.70
1759954165,2025-10-08 22:09:25,tqdlZltV64y1hKqfYra+iVMYfkciD+uJokAtEhJzcik=,Thierry,0,0,0.00,0.00,0.00
```

**Parsing Logic:**
```typescript
// Skip section headers (=== WireGuard Bandwidth Log ===)
if (line.startsWith('===')) continue;

// Split CSV and extract fields
const [unixTimestamp, datetime, publicKey, clientName, rxBytes, txBytes, rxMB, txMB, totalMB] = line.split(',');

// Convert to Date object for filtering
const timestamp = new Date(parseInt(unixTimestamp) * 1000);

// Filter by period (24h, 168h, 720h)
const hoursDiff = (now.getTime() - timestamp.getTime()) / (1000 * 60 * 60);
if (period === 'today' && hoursDiff > 24) continue;
```

## Deployment

### Current Production Deployment

**Container Status:**
```bash
ssh root@wg.accelior.com 'docker ps | grep wireguard-dashboard'
# wireguard-dashboard running on 0.0.0.0:3001
```

**Deployment Date:** 2025-10-10
**Container ID:** 12579e989bd1
**Image:** wireguard-dashboard:latest (linux/amd64)

### Step-by-Step Deployment Process

#### 1. Build Docker Image for Production

**IMPORTANT:** Must build for `linux/amd64` (WireGuard server architecture):

```bash
cd /Users/jm/Codebase/internet-control/wireguard-dashboard

# Build for correct platform
docker buildx build --platform linux/amd64 -t wireguard-dashboard .
```

**Build Output Verification:**
```bash
docker images | grep wireguard-dashboard
# wireguard-dashboard  latest  054aa96700cc  147MB
```

#### 2. Transfer Image to Server

```bash
# Stream image directly to server
docker save wireguard-dashboard | ssh root@wg.accelior.com 'docker load'
```

**Expected Output:**
```
Loaded image: wireguard-dashboard:latest
```

#### 3. Deploy Container with Volume Mount

```bash
ssh root@wg.accelior.com 'docker run -d \
  --name wireguard-dashboard \
  -p 3001:3001 \
  -v /var/log/wireguard:/var/log/wireguard:ro \
  --restart unless-stopped \
  wireguard-dashboard'
```

**Key Configuration:**
- `-p 3001:3001` - Expose dashboard on port 3001
- `-v /var/log/wireguard:/var/log/wireguard:ro` - Mount logs as **read-only**
- `--restart unless-stopped` - Auto-restart on reboot
- Runs as non-root user (nextjs:1001) inside container

#### 4. Verify Deployment

```bash
# Check container is running
ssh root@wg.accelior.com 'docker ps | grep wireguard-dashboard'

# View startup logs
ssh root@wg.accelior.com 'docker logs wireguard-dashboard --tail 20'

# Test API endpoint
curl http://wg.accelior.com:3001/api/bandwidth?period=today

# Test web interface
curl -I http://wg.accelior.com:3001
```

**Expected API Response:**
```json
[
  {
    "timestamp": "2025-10-10T09:00:01.000Z",
    "clientName": "JM MacBook Pro",
    "rxMB": 186.75,
    "txMB": 580.47,
    "totalMB": 767.22
  }
]
```

### Redeployment Process (Updates)

When updating the dashboard with new features:

```bash
# 1. Build new image
cd /Users/jm/Codebase/internet-control/wireguard-dashboard
docker buildx build --platform linux/amd64 -t wireguard-dashboard .

# 2. Transfer to server
docker save wireguard-dashboard | ssh root@wg.accelior.com 'docker load'

# 3. Stop and remove old container
ssh root@wg.accelior.com 'docker stop wireguard-dashboard && docker rm wireguard-dashboard'

# 4. Start new container (same command as initial deployment)
ssh root@wg.accelior.com 'docker run -d \
  --name wireguard-dashboard \
  -p 3001:3001 \
  -v /var/log/wireguard:/var/log/wireguard:ro \
  --restart unless-stopped \
  wireguard-dashboard'

# 5. Verify
ssh root@wg.accelior.com 'docker logs wireguard-dashboard --tail 10'
```

Access at: http://wg.accelior.com:3001

### Option 2: Standalone Deployment

```bash
# Build for production
cd /Users/jm/Codebase/internet-control/wireguard-dashboard
npm run build

# Copy to server
scp -r .next/standalone/* root@wg.accelior.com:/opt/wireguard-dashboard/
scp -r .next/static root@wg.accelior.com:/opt/wireguard-dashboard/.next/
scp -r public root@wg.accelior.com:/opt/wireguard-dashboard/

# Create systemd service on server
ssh root@wg.accelior.com 'cat > /etc/systemd/system/wireguard-dashboard.service << EOL
[Unit]
Description=WireGuard Bandwidth Dashboard
After=network.target

[Service]
Type=simple
User=root
WorkingDirectory=/opt/wireguard-dashboard
ExecStart=/usr/bin/node server.js
Restart=always
Environment=PORT=3001
Environment=HOSTNAME=0.0.0.0

[Install]
WantedBy=multi-user.target
EOL'

# Start service
ssh root@wg.accelior.com 'systemctl daemon-reload && systemctl enable wireguard-dashboard && systemctl start wireguard-dashboard'
```

### Option 3: Nginx Reverse Proxy (Production Setup)

Add to WireGuard server's nginx config:

```nginx
server {
    listen 80;
    server_name wg-stats.accelior.com;  # Use your domain

    location / {
        proxy_pass http://localhost:3001;
        proxy_http_version 1.1;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection 'upgrade';
        proxy_set_header Host $host;
        proxy_cache_bypass $http_upgrade;
    }
}
```

Then add SSL with Let's Encrypt:
```bash
ssh root@wg.accelior.com 'certbot --nginx -d wg-stats.accelior.com'
```

## Technical Details

### Dependencies
```json
{
  "next": "14.2.18",
  "react": "^18",
  "react-dom": "^18",
  "recharts": "^2.12.7",
  "date-fns": "^3.6.0",
  "lucide-react": "^0.441.0",
  "@radix-ui/react-tabs": "^1.1.1",
  "@radix-ui/react-select": "^2.1.2",
  "@radix-ui/react-slot": "^1.1.0",
  "class-variance-authority": "^0.7.0",
  "clsx": "^2.1.1",
  "tailwind-merge": "^2.5.4",
  "tailwindcss": "^3.4.1",
  "tailwindcss-animate": "^1.0.7"
}
```

### Component Architecture

**Application Structure (Next.js 14 App Router):**
```
app/
├── layout.tsx              # Root layout with metadata, fonts
├── page.tsx                # Main dashboard (client component)
├── globals.css             # Tailwind + shadcn base styles
└── api/
    └── bandwidth/
        └── route.ts        # API endpoint (server-side)
```

**Component Hierarchy:**
```
Dashboard (page.tsx) - Client Component
├── Stats Cards (3x Card components)
│   ├── Total Download
│   ├── Total Upload
│   └── Total Bandwidth
├── Tabs Component (Timeline / By Client)
│   ├── Timeline Tab
│   │   └── AreaChart (Recharts)
│   │       ├── XAxis (hourly timestamps)
│   │       ├── YAxis (MB)
│   │       ├── Tooltip
│   │       └── Area layers (per client)
│   └── Clients Tab
│       ├── BarChart (Recharts)
│       │   ├── XAxis (client names)
│       │   ├── YAxis (MB)
│       │   ├── Tooltip
│       │   └── Bars (download/upload)
│       └── Data Table (client breakdown)
```

**shadcn/ui Components Used:**
- `Card` - Stat cards, chart containers
- `Tabs` - Timeline vs Client view switching
- `Select` - Period selection (future)
- Custom variants with `class-variance-authority`

### Data Flow Architecture

```
┌─────────────────────────────────────────────────────────────┐
│ WireGuard Server (wg.accelior.com)                          │
│                                                              │
│  ┌──────────────┐         ┌─────────────────┐              │
│  │ wg-stats     │ writes  │ /var/log/       │              │
│  │ cron job     ├────────>│ wireguard/      │              │
│  │ (hourly)     │         │ bandwidth-*.log │              │
│  └──────────────┘         └────────┬────────┘              │
│                                     │                        │
│                                     │ mounted as :ro volume  │
│                                     │                        │
│  ┌──────────────────────────────────┴─────────────────┐    │
│  │ Docker Container: wireguard-dashboard              │    │
│  │                                                     │    │
│  │  ┌────────────────────────────────────────┐        │    │
│  │  │ Next.js API Route                      │        │    │
│  │  │ /api/bandwidth/route.ts                │        │    │
│  │  │                                         │        │    │
│  │  │  1. Read log files                     │        │    │
│  │  │  2. Parse CSV format                   │        │    │
│  │  │  3. Filter by period (24h/7d/30d)     │        │    │
│  │  │  4. Return JSON                        │        │    │
│  │  └────────────┬───────────────────────────┘        │    │
│  │               │                                     │    │
│  │               │ HTTP response                       │    │
│  │               │                                     │    │
│  │  ┌────────────┴───────────────────────────┐        │    │
│  │  │ Dashboard Frontend (page.tsx)          │        │    │
│  │  │                                         │        │    │
│  │  │  1. Fetch data every 60s               │        │    │
│  │  │  2. Aggregate hourly                   │        │    │
│  │  │  3. Render charts (Recharts)           │        │    │
│  │  │  4. Update stats                       │        │    │
│  │  └─────────────────────────────────────────┘        │    │
│  │                                                     │    │
│  │  Port 3001 exposed to host                         │    │
│  └─────────────────────────────────────────────────────┘    │
│                                                              │
└─────────────────────────────────────────────────────────────┘
                        │
                        │ HTTP
                        ▼
                 User Browser
```

### Key Implementation Decisions

**1. Server Components vs Client Components**
- **Layout**: Server component (static, no interactivity)
- **Dashboard page**: Client component ('use client') for state management and auto-refresh
- **API route**: Server-side for file system access

**2. Data Aggregation Strategy**
- **Hourly Rollup**: Group log entries by hour using `date-fns`
- **Client Separation**: Aggregate per client (JM MacBook Pro, Thierry)
- **Stacked Areas**: Show multiple clients on same timeline
- **Performance**: Pre-aggregate in API, not in frontend

**3. Chart Configuration**
```typescript
// Timeline: Stacked Area Chart
<AreaChart data={hourlyData}>
  <XAxis
    dataKey="time"
    tickFormatter={(value) => format(new Date(value), 'HH:mm')}
  />
  <YAxis />
  <Tooltip
    formatter={(value: number) => `${value.toFixed(2)} MB`}
  />
  <Area
    dataKey="JM MacBook Pro"
    stackId="1"
    stroke="#8884d8"
    fill="#8884d8"
  />
  <Area
    dataKey="Thierry"
    stackId="1"
    stroke="#82ca9d"
    fill="#82ca9d"
  />
</AreaChart>

// Client Comparison: Grouped Bar Chart
<BarChart data={clientStats}>
  <XAxis dataKey="name" />
  <YAxis />
  <Tooltip formatter={(value: number) => `${value.toFixed(2)} MB`} />
  <Legend />
  <Bar dataKey="download" fill="#8884d8" name="Download" />
  <Bar dataKey="upload" fill="#82ca9d" name="Upload" />
</BarChart>
```

**4. Error Handling**
- Try/catch around file reading
- Graceful fallback to mock data
- Empty state handling in charts
- Console logging for debugging

### Performance Optimizations
- **Auto-refresh**: 60 seconds (configurable in `page.tsx`)
- **Efficient parsing**: CSV split + filter, no regex
- **Data aggregation**: Hourly rollups reduce chart complexity
- **Standalone build**: Next.js standalone output (~50MB vs ~150MB)
- **Static generation**: Pre-rendered where possible
- **Docker multi-stage**: Separate build and runtime stages (147MB final image)

## Customization

### Change Refresh Interval
Edit `app/page.tsx`:
```typescript
const interval = setInterval(fetchData, 60000); // Change to desired interval in ms
```

### Change Chart Colors
Edit `app/page.tsx`:
```typescript
<Area dataKey="JM MacBook Pro" stroke="#8884d8" fill="#8884d8" />
<Area dataKey="Thierry" stroke="#82ca9d" fill="#82ca9d" />
```

### Add More Periods
Edit `app/page.tsx` to add buttons for week/month views:
```typescript
const [period, setPeriod] = useState('today'); // 'today', 'week', 'month'
```

## Troubleshooting

### Common Issues Encountered During Development/Deployment

#### Issue 1: Platform Architecture Mismatch

**Symptoms:**
```
WARNING: The requested image's platform (linux/arm64) does not match the detected host platform (linux/amd64/v4)
```

**Cause:** Built Docker image on Mac (ARM64) but server is AMD64

**Solution:**
```bash
# Always specify platform when building
docker buildx build --platform linux/amd64 -t wireguard-dashboard .
```

#### Issue 2: TypeScript Build Error - "Cannot find name 'period'"

**Symptoms:**
```
Type error: Cannot find name 'period'.
./app/api/bandwidth/route.ts:27:39
```

**Cause:** Variable `period` was inside try block but referenced in catch block

**Solution:**
```typescript
// Move variable declaration outside try/catch
export async function GET(request: Request) {
  const { searchParams } = new URL(request.url);
  const period = searchParams.get('period') || 'today';

  try {
    // ... code
  } catch (error) {
    // Now 'period' is in scope
    const mockData = generateMockData(period);
  }
}
```

#### Issue 3: Docker Build Failed - "/app/public: not found"

**Symptoms:**
```
ERROR: failed to calculate checksum of ref: "/app/public": not found
```

**Cause:** Missing `public/` directory in project

**Solution:**
```bash
# Create empty public directory
mkdir -p public
touch public/.gitkeep

# Update Dockerfile to handle missing public gracefully
COPY --from=builder /app/public ./public 2>/dev/null || true
```

#### Issue 4: Charts Show "0.00 MB" Despite Real Data

**Symptoms:**
- API returns data correctly
- Dashboard displays but shows zero values

**Debugging:**
```bash
# Check API response
curl http://localhost:3001/api/bandwidth?period=today | jq '.[0]'

# Check browser console (F12) for errors
# Check if data aggregation is working
```

**Common Causes:**
- Clock skew (server time vs log timestamps)
- Period filter too restrictive
- Data not being aggregated correctly

**Solution:**
```typescript
// Add debug logging
console.log('Raw data entries:', data.length);
console.log('First entry:', data[0]);
console.log('Time diff:', hoursDiff);
```

### General Troubleshooting Steps

#### Port Already in Use
```bash
# Kill process on port 3001
lsof -ti:3001 | xargs kill -9

# Or use different port
PORT=3002 npm run dev
```

#### Container Won't Start
```bash
# Check container logs
ssh root@wg.accelior.com 'docker logs wireguard-dashboard'

# Check if port is already in use
ssh root@wg.accelior.com 'netstat -tlnp | grep 3001'

# Verify volume mount exists
ssh root@wg.accelior.com 'ls -la /var/log/wireguard/'
```

#### API Returns Empty Array
```bash
# Check log files exist
ssh root@wg.accelior.com 'ls -la /var/log/wireguard/bandwidth-*.log'

# Check file permissions
ssh root@wg.accelior.com 'ls -l /var/log/wireguard/bandwidth-*.log'

# Check log format
ssh root@wg.accelior.com 'head -20 /var/log/wireguard/bandwidth-*.log'

# Test API directly from server
ssh root@wg.accelior.com 'curl http://localhost:3001/api/bandwidth?period=today'
```

#### Charts Not Showing
1. Check browser console for errors (F12)
2. Verify API endpoint returns data: `curl http://localhost:3001/api/bandwidth`
3. Check recharts is installed: `npm list recharts`
4. Verify data structure matches expected format
5. Check if ResponsiveContainer has proper height

#### Data Not Updating
1. Check logs are being written: `ls -la /var/log/wireguard/`
2. Verify cron job is running: `crontab -l | grep wg-stats`
3. Check container has read access to log volume
4. Verify auto-refresh is working (check Network tab in browser)

#### Build Failures
```bash
# Clear Docker cache
docker system prune -a

# Clear npm cache
npm cache clean --force
rm -rf node_modules package-lock.json
npm install

# Check for TypeScript errors
npm run build
```

## Monitoring & Logs

### Application Logs (Docker)
```bash
ssh root@wg.accelior.com 'docker logs wireguard-dashboard -f'
```

### Application Logs (Systemd)
```bash
ssh root@wg.accelior.com 'journalctl -u wireguard-dashboard -f'
```

### Access Logs
Dashboard logs all API requests to stdout (captured by Docker/systemd).

## Security Considerations

1. **No Authentication**: Dashboard is publicly accessible on port 3001
   - Add nginx basic auth if needed
   - Or restrict to VPN clients only

2. **Read-Only Access**: Dashboard only reads logs, cannot modify VPN config

3. **CORS**: API endpoints are same-origin only

## Future Enhancements & Iteration Guide

### Planned Improvements

**Priority 1 (High Value):**
- 📊 **Period Selection**: Add buttons for Today/Week/Month
- 📈 **Historical Trends**: Show week-over-week comparison
- 🔔 **Bandwidth Alerts**: Email/Slack notifications for thresholds
- 📥 **Data Export**: CSV/Excel download button

**Priority 2 (Nice to Have):**
- 🔐 **Authentication**: Basic auth or OAuth
- 📱 **PWA Support**: Install as app, offline mode
- 🎨 **Theme Toggle**: Manual dark/light mode switch
- 🌓 **Per-Client Colors**: Dynamic color assignment

**Priority 3 (Advanced):**
- 🔄 **WebSockets**: Real-time updates instead of polling
- 📊 **More Charts**: Pie charts (per-client %), gauges
- 🌍 **Multi-language**: i18n support
- 📈 **Long-term Storage**: Archive data beyond 90 days

### How to Add Features - Step-by-Step Guide

#### Example: Adding Period Selection (Today/Week/Month)

**1. Update Frontend State (`app/page.tsx`)**

```typescript
// Add state for period selection
const [period, setPeriod] = useState<'today' | 'week' | 'month'>('today');

// Update fetch function to use period
const fetchData = async () => {
  const response = await fetch(`/api/bandwidth?period=${period}`);
  // ... rest of fetch logic
};

// Add useEffect dependency
useEffect(() => {
  fetchData();
  const interval = setInterval(fetchData, 60000);
  return () => clearInterval(interval);
}, [period]); // Re-fetch when period changes
```

**2. Add UI Controls**

```typescript
// Add button group before Tabs
<div className="flex gap-2 mb-4">
  <button
    onClick={() => setPeriod('today')}
    className={`px-4 py-2 rounded ${period === 'today' ? 'bg-blue-600 text-white' : 'bg-gray-200'}`}
  >
    Today
  </button>
  <button
    onClick={() => setPeriod('week')}
    className={`px-4 py-2 rounded ${period === 'week' ? 'bg-blue-600 text-white' : 'bg-gray-200'}`}
  >
    Week
  </button>
  <button
    onClick={() => setPeriod('month')}
    className={`px-4 py-2 rounded ${period === 'month' ? 'bg-blue-600 text-white' : 'bg-gray-200'}`}
  >
    Month
  </button>
</div>
```

**3. Update API Endpoint (Already Supports This!)**

The `app/api/bandwidth/route.ts` already handles period parameter:
- `today` - Last 24 hours
- `week` - Last 7 days (168 hours)
- `month` - Last 30 days (720 hours)

**4. Test & Deploy**

```bash
# Test locally
npm run dev
# Visit http://localhost:3001

# Build and deploy
docker buildx build --platform linux/amd64 -t wireguard-dashboard .
docker save wireguard-dashboard | ssh root@wg.accelior.com 'docker load'
ssh root@wg.accelior.com 'docker stop wireguard-dashboard && docker rm wireguard-dashboard'
ssh root@wg.accelior.com 'docker run -d --name wireguard-dashboard -p 3001:3001 -v /var/log/wireguard:/var/log/wireguard:ro --restart unless-stopped wireguard-dashboard'
```

#### Example: Adding Data Export (CSV Download)

**1. Create Export Function (`app/page.tsx`)**

```typescript
const exportToCSV = () => {
  const csv = [
    'Timestamp,Client Name,Download (MB),Upload (MB),Total (MB)',
    ...data.map(entry =>
      `${entry.timestamp},${entry.clientName},${entry.rxMB},${entry.txMB},${entry.totalMB}`
    )
  ].join('\n');

  const blob = new Blob([csv], { type: 'text/csv' });
  const url = window.URL.createObjectURL(blob);
  const a = document.createElement('a');
  a.href = url;
  a.download = `wireguard-bandwidth-${period}-${new Date().toISOString().slice(0, 10)}.csv`;
  a.click();
};
```

**2. Add Export Button**

```typescript
import { Download } from 'lucide-react';

<button
  onClick={exportToCSV}
  className="flex items-center gap-2 px-4 py-2 bg-green-600 text-white rounded hover:bg-green-700"
>
  <Download className="w-4 h-4" />
  Export CSV
</button>
```

#### Example: Adding Authentication (Basic Auth via Nginx)

**1. Install Apache Utils on Server**

```bash
ssh root@wg.accelior.com 'apt-get install apache2-utils'
```

**2. Create Password File**

```bash
ssh root@wg.accelior.com 'htpasswd -c /etc/nginx/.htpasswd admin'
# Enter password when prompted
```

**3. Update Nginx Config**

```nginx
location / {
    proxy_pass http://localhost:3001;

    # Add authentication
    auth_basic "WireGuard Dashboard";
    auth_basic_user_file /etc/nginx/.htpasswd;

    # Proxy headers
    proxy_http_version 1.1;
    proxy_set_header Upgrade $http_upgrade;
    proxy_set_header Connection 'upgrade';
    proxy_set_header Host $host;
    proxy_cache_bypass $http_upgrade;
}
```

**4. Reload Nginx**

```bash
ssh root@wg.accelior.com 'nginx -t && systemctl reload nginx'
```

### Common Modification Patterns

**Adding a New Chart:**
1. Import from Recharts: `import { PieChart, Pie } from 'recharts'`
2. Add to `page.tsx` in appropriate tab
3. Transform data to chart format
4. Configure colors and labels

**Changing Color Scheme:**
- Edit Tailwind classes in `app/page.tsx`
- Update chart colors in `<Area stroke="..." fill="..." />`
- Modify `tailwind.config.ts` for custom colors

**Adding New shadcn/ui Components:**
```bash
# Run shadcn CLI
npx shadcn-ui@latest add button
npx shadcn-ui@latest add select
npx shadcn-ui@latest add dialog
```

**Modifying Log Parsing:**
- Edit `readBandwidthLogs()` in `app/api/bandwidth/route.ts`
- Update CSV split logic if format changes
- Add error handling for malformed lines

### Development Best Practices

**Local Testing:**
1. Always test locally first: `npm run dev`
2. Check browser console for errors (F12)
3. Test API endpoint: `curl http://localhost:3001/api/bandwidth`
4. Verify charts render correctly

**TypeScript Types:**
```typescript
// Always define interfaces for data structures
interface BandwidthEntry {
  timestamp: string;
  clientName: string;
  rxMB: number;
  txMB: number;
  totalMB: number;
}

// Use strict type checking
const data: BandwidthEntry[] = await fetchData();
```

**Error Handling:**
```typescript
// Always wrap API calls in try/catch
try {
  const response = await fetch('/api/bandwidth');
  if (!response.ok) throw new Error('Failed to fetch');
  const data = await response.json();
} catch (error) {
  console.error('Error:', error);
  setError('Failed to load bandwidth data');
}
```

**Docker Gotchas:**
- Always build for `linux/amd64` platform
- Test locally before pushing to production
- Check logs immediately after deployment
- Keep `public/` directory (even if empty) for Docker build

### Files to Modify by Feature

| Feature | Files to Edit |
|---------|--------------|
| UI Changes | `app/page.tsx`, `app/globals.css` |
| New shadcn components | `components/ui/*.tsx` |
| API logic | `app/api/bandwidth/route.ts` |
| Chart config | `app/page.tsx` (chart components) |
| Metadata/SEO | `app/layout.tsx` |
| Styling | `tailwind.config.ts`, `app/globals.css` |
| Dependencies | `package.json` |
| Docker build | `Dockerfile`, `.dockerignore` |
| TypeScript config | `tsconfig.json` |

## Related Documentation

- [Bandwidth Tracking System](bandwidth-tracking.md)
- [WireGuard Easy Migration](wireguard-easy-migration.md)
- [WireGuard Technical Docs](wireguard-technical-documentation.md)

---

**Created**: 2025-10-09
**Last Updated**: 2025-10-10
**Maintainer**: Infrastructure Team
**Status**: ✅ Production Deployed
**Container ID**: 12579e989bd1
**Image**: wireguard-dashboard:latest (147MB)

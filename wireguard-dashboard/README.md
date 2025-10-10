# WireGuard Bandwidth Dashboard

Modern Next.js dashboard for monitoring WireGuard VPN bandwidth usage with beautiful shadcn/ui components.

## Features

- ✨ Real-time bandwidth monitoring
- 📊 Interactive charts (area charts, bar charts)
- 👥 Per-client bandwidth tracking
- 📱 Responsive design
- 🎨 Modern UI with shadcn/ui components
- 🔄 Auto-refresh every minute

## Tech Stack

- **Framework**: Next.js 14 (App Router)
- **UI Components**: shadcn/ui (Radix UI + Tailwind CSS)
- **Charts**: Recharts
- **Styling**: Tailwind CSS
- **TypeScript**: Full type safety

## Development

```bash
# Install dependencies
npm install

# Run development server
npm run dev

# Build for production
npm run build

# Start production server
npm start
```

Open [http://localhost:3001](http://localhost:3001) to view the dashboard.

## API Integration

The dashboard reads bandwidth logs from `/var/log/wireguard/bandwidth-*.log` files created by the `wg-stats-logger.sh` script.

### Log Format
```csv
unix_timestamp,datetime,public_key,client_name,rx_bytes,tx_bytes,rx_mb,tx_mb,total_mb
```

## Deployment

### Docker Deployment

```bash
# Build Docker image
docker build -t wireguard-dashboard .

# Run container
docker run -d \
  --name wireguard-dashboard \
  -p 3001:3001 \
  -v /var/log/wireguard:/var/log/wireguard:ro \
  wireguard-dashboard
```

### Manual Deployment

```bash
# Build the application
npm run build

# Copy .next/standalone to server
scp -r .next/standalone/* root@wg.accelior.com:/opt/wireguard-dashboard/

# Run on server
cd /opt/wireguard-dashboard && node server.js
```

## License

MIT

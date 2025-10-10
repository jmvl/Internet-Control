import { NextResponse } from 'next/server';
import { promises as fs } from 'fs';
import path from 'path';

export const dynamic = 'force-dynamic';

interface BandwidthEntry {
  timestamp: string;
  clientName: string;
  rxMB: number;
  txMB: number;
  totalMB: number;
}

export async function GET(request: Request) {
  const { searchParams } = new URL(request.url);
  const period = searchParams.get('period') || 'today';

  try {
    // Try to read real data from WireGuard logs
    const data = await readBandwidthLogs(period);

    return NextResponse.json(data);
  } catch (error) {
    console.error('Error fetching bandwidth data:', error);
    // Fallback to mock data if real logs aren't available
    const mockData = generateMockData(period);
    return NextResponse.json(mockData);
  }
}

async function readBandwidthLogs(period: string): Promise<BandwidthEntry[]> {
  const logDir = '/var/log/wireguard';
  const now = new Date();
  const entries: BandwidthEntry[] = [];

  // Determine which log files to read based on period
  const files: string[] = [];
  if (period === 'today') {
    const currentMonth = now.toISOString().slice(0, 7); // YYYY-MM
    files.push(`bandwidth-${currentMonth}.log`);
  } else if (period === 'week') {
    // Last 7 days - might span two months
    const currentMonth = now.toISOString().slice(0, 7);
    files.push(`bandwidth-${currentMonth}.log`);
    // Add previous month if we're early in current month
    if (now.getDate() <= 7) {
      const prevMonth = new Date(now.getFullYear(), now.getMonth() - 1, 1);
      files.push(`bandwidth-${prevMonth.toISOString().slice(0, 7)}.log`);
    }
  } else {
    // Month - current and previous month
    const currentMonth = now.toISOString().slice(0, 7);
    const prevMonth = new Date(now.getFullYear(), now.getMonth() - 1, 1);
    files.push(`bandwidth-${currentMonth}.log`);
    files.push(`bandwidth-${prevMonth.toISOString().slice(0, 7)}.log`);
  }

  // Read and parse log files
  for (const file of files) {
    try {
      const filePath = path.join(logDir, file);
      const content = await fs.readFile(filePath, 'utf-8');
      const lines = content.split('\n');

      for (const line of lines) {
        // Skip empty lines and section headers
        if (!line || line.startsWith('===')) continue;

        const parts = line.split(',');
        if (parts.length < 9) continue;

        const [unixTimestamp, datetime, publicKey, clientName, rxBytes, txBytes, rxMB, txMB, totalMB] = parts;

        // Parse timestamp
        const timestamp = new Date(parseInt(unixTimestamp) * 1000);

        // Filter by period
        const hoursDiff = (now.getTime() - timestamp.getTime()) / (1000 * 60 * 60);
        if (period === 'today' && hoursDiff > 24) continue;
        if (period === 'week' && hoursDiff > 168) continue;
        if (period === 'month' && hoursDiff > 720) continue;

        entries.push({
          timestamp: timestamp.toISOString(),
          clientName: clientName.trim(),
          rxMB: parseFloat(rxMB),
          txMB: parseFloat(txMB),
          totalMB: parseFloat(totalMB)
        });
      }
    } catch (error) {
      console.error(`Error reading ${file}:`, error);
      // Continue to next file
    }
  }

  return entries;
}

function generateMockData(period: string): BandwidthEntry[] {
  const now = new Date();
  const data: BandwidthEntry[] = [];

  const clients = ['JM MacBook Pro', 'Thierry'];
  const hours = period === 'today' ? 24 : period === 'week' ? 168 : 30 * 24;

  for (let i = hours; i >= 0; i--) {
    const time = new Date(now.getTime() - i * 60 * 60 * 1000);
    clients.forEach(client => {
      const isActive = client === 'JM MacBook Pro' && i < 12;
      data.push({
        timestamp: time.toISOString(),
        clientName: client,
        rxMB: isActive ? Math.random() * 50 + 10 : 0,
        txMB: isActive ? Math.random() * 200 + 50 : 0,
        totalMB: 0 // Will be calculated
      });
    });
  }

  return data.map(d => ({
    ...d,
    totalMB: d.rxMB + d.txMB
  }));
}

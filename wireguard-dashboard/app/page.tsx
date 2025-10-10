'use client';

import { useEffect, useState } from 'react';
import { Card, CardContent, CardDescription, CardHeader, CardTitle } from "@/components/ui/card";
import { Tabs, TabsContent, TabsList, TabsTrigger } from "@/components/ui/tabs";
import { ThemeToggle } from "@/components/theme-toggle";
import { AreaChart, Area, BarChart, Bar, XAxis, YAxis, CartesianGrid, Tooltip, Legend, ResponsiveContainer } from 'recharts';
import { Activity, Download, Upload, Wifi } from 'lucide-react';

interface BandwidthEntry {
  timestamp: string;
  clientName: string;
  rxMB: number;
  txMB: number;
  totalMB: number;
}

interface ClientStats {
  name: string;
  download: number;
  upload: number;
  total: number;
}

export default function Dashboard() {
  const [data, setData] = useState<BandwidthEntry[]>([]);
  const [loading, setLoading] = useState(true);
  const [period, setPeriod] = useState('today');

  useEffect(() => {
    fetchData();
    const interval = setInterval(fetchData, 60000); // Refresh every minute
    return () => clearInterval(interval);
  }, [period]);

  const fetchData = async () => {
    try {
      const response = await fetch(`/api/bandwidth?period=${period}`);
      const json = await response.json();
      setData(json);
    } catch (error) {
      console.error('Failed to fetch bandwidth data:', error);
    } finally {
      setLoading(false);
    }
  };

  // Aggregate data by hour
  const hourlyData = data.reduce((acc: any[], entry) => {
    const hour = new Date(entry.timestamp).toLocaleTimeString('en-US', {
      hour: '2-digit',
      minute: '2-digit'
    });

    const existing = acc.find(item => item.time === hour);
    if (existing) {
      if (!existing[entry.clientName]) {
        existing[entry.clientName] = 0;
      }
      existing[entry.clientName] += entry.totalMB;
      existing.total += entry.totalMB;
    } else {
      acc.push({
        time: hour,
        [entry.clientName]: entry.totalMB,
        total: entry.totalMB
      });
    }
    return acc;
  }, []).slice(-24); // Last 24 hours

  // Get client stats
  const clientStats: ClientStats[] = Array.from(
    data.reduce((acc, entry) => {
      if (!acc.has(entry.clientName)) {
        acc.set(entry.clientName, { name: entry.clientName, download: 0, upload: 0, total: 0 });
      }
      const stats = acc.get(entry.clientName)!;
      stats.download += entry.rxMB;
      stats.upload += entry.txMB;
      stats.total += entry.totalMB;
      return acc;
    }, new Map<string, ClientStats>()).values()
  );

  const totalDownload = clientStats.reduce((sum, client) => sum + client.download, 0);
  const totalUpload = clientStats.reduce((sum, client) => sum + client.upload, 0);
  const totalBandwidth = totalDownload + totalUpload;

  return (
    <div className="min-h-screen bg-gradient-to-br from-slate-50 to-slate-100 dark:from-slate-900 dark:to-slate-800">
      <div className="container mx-auto p-6">
        {/* Header */}
        <div className="mb-8">
          <div className="flex items-center justify-between mb-2">
            <div className="flex items-center gap-3">
              <Wifi className="w-8 h-8 text-blue-600 dark:text-blue-400" />
              <h1 className="text-4xl font-bold text-slate-900 dark:text-white">
                WireGuard Bandwidth Monitor
              </h1>
            </div>
            <ThemeToggle />
          </div>
          <p className="text-slate-600 dark:text-slate-400">
            Real-time bandwidth tracking for wg.accelior.com
          </p>
        </div>

        {/* Stats Cards */}
        <div className="grid grid-cols-1 md:grid-cols-3 gap-6 mb-8">
          <Card>
            <CardHeader className="flex flex-row items-center justify-between space-y-0 pb-2">
              <CardTitle className="text-sm font-medium">Total Download</CardTitle>
              <Download className="h-4 w-4 text-muted-foreground" />
            </CardHeader>
            <CardContent>
              <div className="text-2xl font-bold">{totalDownload.toFixed(2)} MB</div>
              <p className="text-xs text-muted-foreground">
                Last 24 hours
              </p>
            </CardContent>
          </Card>

          <Card>
            <CardHeader className="flex flex-row items-center justify-between space-y-0 pb-2">
              <CardTitle className="text-sm font-medium">Total Upload</CardTitle>
              <Upload className="h-4 w-4 text-muted-foreground" />
            </CardHeader>
            <CardContent>
              <div className="text-2xl font-bold">{totalUpload.toFixed(2)} MB</div>
              <p className="text-xs text-muted-foreground">
                Last 24 hours
              </p>
            </CardContent>
          </Card>

          <Card>
            <CardHeader className="flex flex-row items-center justify-between space-y-0 pb-2">
              <CardTitle className="text-sm font-medium">Total Bandwidth</CardTitle>
              <Activity className="h-4 w-4 text-muted-foreground" />
            </CardHeader>
            <CardContent>
              <div className="text-2xl font-bold">{totalBandwidth.toFixed(2)} MB</div>
              <p className="text-xs text-muted-foreground">
                Last 24 hours
              </p>
            </CardContent>
          </Card>
        </div>

        {/* Charts */}
        <Tabs defaultValue="timeline" className="space-y-4">
          <TabsList>
            <TabsTrigger value="timeline">Timeline</TabsTrigger>
            <TabsTrigger value="clients">By Client</TabsTrigger>
          </TabsList>

          <TabsContent value="timeline" className="space-y-4">
            <Card>
              <CardHeader>
                <CardTitle>Bandwidth Usage Over Time</CardTitle>
                <CardDescription>
                  Hourly bandwidth consumption for the last 24 hours
                </CardDescription>
              </CardHeader>
              <CardContent>
                <ResponsiveContainer width="100%" height={400}>
                  <AreaChart data={hourlyData}>
                    <CartesianGrid strokeDasharray="3 3" />
                    <XAxis dataKey="time" />
                    <YAxis label={{ value: 'MB', angle: -90, position: 'insideLeft' }} />
                    <Tooltip />
                    <Legend />
                    <Area
                      type="monotone"
                      dataKey="JM MacBook Pro"
                      stackId="1"
                      stroke="#8884d8"
                      fill="#8884d8"
                    />
                    <Area
                      type="monotone"
                      dataKey="Thierry"
                      stackId="1"
                      stroke="#82ca9d"
                      fill="#82ca9d"
                    />
                  </AreaChart>
                </ResponsiveContainer>
              </CardContent>
            </Card>
          </TabsContent>

          <TabsContent value="clients" className="space-y-4">
            <Card>
              <CardHeader>
                <CardTitle>Bandwidth by Client</CardTitle>
                <CardDescription>
                  Total bandwidth usage per VPN client
                </CardDescription>
              </CardHeader>
              <CardContent>
                <ResponsiveContainer width="100%" height={400}>
                  <BarChart data={clientStats}>
                    <CartesianGrid strokeDasharray="3 3" />
                    <XAxis dataKey="name" />
                    <YAxis label={{ value: 'MB', angle: -90, position: 'insideLeft' }} />
                    <Tooltip />
                    <Legend />
                    <Bar dataKey="download" fill="#8884d8" name="Download" />
                    <Bar dataKey="upload" fill="#82ca9d" name="Upload" />
                  </BarChart>
                </ResponsiveContainer>
              </CardContent>
            </Card>

            {/* Client Details Table */}
            <Card>
              <CardHeader>
                <CardTitle>Client Details</CardTitle>
                <CardDescription>
                  Detailed breakdown of bandwidth usage
                </CardDescription>
              </CardHeader>
              <CardContent>
                <div className="space-y-4">
                  {clientStats.map((client) => (
                    <div key={client.name} className="flex items-center justify-between border-b pb-4">
                      <div className="space-y-1">
                        <p className="text-sm font-medium leading-none">{client.name}</p>
                        <p className="text-sm text-muted-foreground">
                          ↓ {client.download.toFixed(2)} MB  •  ↑ {client.upload.toFixed(2)} MB
                        </p>
                      </div>
                      <div className="text-right">
                        <p className="text-sm font-bold">{client.total.toFixed(2)} MB</p>
                        <p className="text-xs text-muted-foreground">Total</p>
                      </div>
                    </div>
                  ))}
                </div>
              </CardContent>
            </Card>
          </TabsContent>
        </Tabs>
      </div>
    </div>
  );
}

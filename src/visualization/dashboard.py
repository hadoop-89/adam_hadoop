"""
Module for generating visualization dashboards from AI results.
"""
import os
import json
import logging
import time
import pandas as pd
import matplotlib.pyplot as plt
import seaborn as sns
import happybase
import dash
from dash import dcc, html
import plotly.express as px
import plotly.graph_objs as go

# Configure logging
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(name)s - %(levelname)s - %(message)s',
    handlers=[logging.FileHandler("visualization.log")]
)
logger = logging.getLogger("visualization")

# Configuration
HBASE_HOST = os.environ.get('HBASE_HOST', 'hbase')
HBASE_PORT = int(os.environ.get('HBASE_PORT', 9090))
DASHBOARD_HOST = os.environ.get('DASHBOARD_HOST', '0.0.0.0')
DASHBOARD_PORT = int(os.environ.get('DASHBOARD_PORT', 8050))
REFRESH_INTERVAL = int(os.environ.get('REFRESH_INTERVAL', 60)) * 1000  # milliseconds

class DataVisualizer:
    def __init__(self):
        """Initialize the data visualization system."""
        self.connection = self._connect_to_hbase()
        self.app = dash.Dash(__name__)
        self._setup_dashboard()
        
    def _connect_to_hbase(self):
        """Connect to HBase."""
        try:
            connection = happybase.Connection(HBASE_HOST, HBASE_PORT)
            logger.info("Connected to HBase")
            return connection
        except Exception as e:
            logger.error(f"Failed to connect to HBase: {str(e)}")
            raise
    
    def _fetch_text_results(self):
        """Fetch text analysis results from HBase."""
        try:
            table = self.connection.table('text_results')
            data = []
            
            for key, values in table.scan():
                row = {'doc_id': key.decode('utf-8')}
                
                # Convert binary values to strings
                for col, value in values.items():
                    col_parts = col.decode('utf-8').split(':')
                    if len(col_parts) == 2:
                        family, qualifier = col_parts
                        row[f"{family}_{qualifier}"] = value.decode('utf-8')
                
                data.append(row)
            
            # Convert to DataFrame
            df = pd.DataFrame(data)
            logger.info(f"Fetched {len(df)} text results")
            return df
        except Exception as e:
            logger.error(f"Failed to fetch text results: {str(e)}")
            return pd.DataFrame()
    
    def _fetch_image_results(self):
        """Fetch image analysis results from HBase."""
        try:
            table = self.connection.table('image_results')
            data = []
            
            for key, values in table.scan():
                row = {'image_id': key.decode('utf-8')}
                
                # Convert binary values to strings
                for col, value in values.items():
                    col_parts = col.decode('utf-8').split(':')
                    if len(col_parts) == 2:
                        family, qualifier = col_parts
                        row[f"{family}_{qualifier}"] = value.decode('utf-8')
                
                data.append(row)
            
            # Convert to DataFrame
            df = pd.DataFrame(data)
            logger.info(f"Fetched {len(df)} image results")
            return df
        except Exception as e:
            logger.error(f"Failed to fetch image results: {str(e)}")
            return pd.DataFrame()
            
    def _setup_dashboard(self):
        """Set up the Dash dashboard layout and callbacks."""
        # Set up the layout
        self.app.layout = html.Div([
            html.H1('AI Analysis Dashboard'),
            
            dcc.Tabs([
                dcc.Tab(label='Text Analysis', children=[
                    html.Div([
                        html.H3('Text Classification Results'),
                        dcc.Graph(id='classification-chart'),
                        
                        html.H3('Sentiment Analysis'),
                        dcc.Graph(id='sentiment-chart'),
                        
                        html.H3('Recent Summaries'),
                        html.Div(id='recent-summaries')
                    ])
                ]),
                
                dcc.Tab(label='Image Analysis', children=[
                    html.Div([
                        html.H3('Object Detection Results'),
                        dcc.Graph(id='detection-chart'),
                        
                        html.H3('Recent Detections'),
                        html.Div(id='recent-detections')
                    ])
                ]),
                
                dcc.Tab(label='Overall Stats', children=[
                    html.Div([
                        html.H3('Processing Volume'),
                        dcc.Graph(id='volume-chart'),
                        
                        html.H3('System Status'),
                        html.Div(id='system-status')
                    ])
                ]),
            ]),
            
            dcc.Interval(
                id='interval-component',
                interval=REFRESH_INTERVAL,
                n_intervals=0
            )
        ])
        
        # Set up callbacks to update graphs
        @self.app.callback(
            [
                dash.dependencies.Output('classification-chart', 'figure'),
                dash.dependencies.Output('sentiment-chart', 'figure'),
                dash.dependencies.Output('recent-summaries', 'children'),
                dash.dependencies.Output('detection-chart', 'figure'),
                dash.dependencies.Output('recent-detections', 'children'),
                dash.dependencies.Output('volume-chart', 'figure'),
                dash.dependencies.Output('system-status', 'children')
            ],
            [dash.dependencies.Input('interval-component', 'n_intervals')]
        )
        def update_graphs(n):
            # This function will be called every REFRESH_INTERVAL to update all plots
            
            # Get data
            text_df = self._fetch_text_results()
            image_df = self._fetch_image_results()
            
            # Generate visualizations
            classification_fig = self._create_classification_chart(text_df)
            sentiment_fig = self._create_sentiment_chart(text_df)
            summaries = self._create_summaries_list(text_df)
            detection_fig = self._create_detection_chart(image_df)
            detections = self._create_detections_list(image_df)
            volume_fig = self._create_volume_chart(text_df, image_df)
            status = self._create_system_status()
            
            return [classification_fig, sentiment_fig, summaries, detection_fig, detections, volume_fig, status]
    
    def _create_classification_chart(self, df):
        """Create a classification results chart."""
        if df.empty:
            return go.Figure().update_layout(title="No classification data available")
        
        # Extract classification columns
        class_cols = [col for col in df.columns if col.startswith('classification_class_') and col.endswith('_name')]
        
        if not class_cols:
            return go.Figure().update_layout(title="No classification data available")
            
        # Count occurrences of each class
        classes = []
        for col in class_cols:
            classes.extend(df[col].dropna().tolist())
        
        class_counts = pd.Series(classes).value_counts().reset_index()
        class_counts.columns = ['Class', 'Count']
        
        fig = px.bar(class_counts, x='Class', y='Count', title='Document Classification Results')
        return fig
    
    def _create_sentiment_chart(self, df):
        """Create a sentiment analysis chart."""
        if df.empty or 'sentiment_label' not in df.columns:
            return go.Figure().update_layout(title="No sentiment data available")
        
        sentiment_counts = df['sentiment_label'].value_counts().reset_index()
        sentiment_counts.columns = ['Sentiment', 'Count']
        
        fig = px.pie(sentiment_counts, names='Sentiment', values='Count', title='Sentiment Analysis Results')
        return fig
    
    def _create_summaries_list(self, df):
        """Create a list of recent summaries."""
        if df.empty or 'summary_text' not in df.columns:
            return html.Div("No summary data available")
        
        # Get the 5 most recent summaries
        recent_df = df.sort_values(by='metadata_timestamp', ascending=False).head(5)
        
        summaries = []
        for _, row in recent_df.iterrows():
            if 'summary_text' in row and pd.notna(row['summary_text']):
                summary_div = html.Div([
                    html.H4(f"Document: {row.get('metadata_doc_id', 'Unknown')}"),
                    html.P(row['summary_text']),
                    html.Hr()
                ])
                summaries.append(summary_div)
        
        if not summaries:
            return html.Div("No summary data available")
            
        return html.Div(summaries)
    
    def _create_detection_chart(self, df):
        """Create an object detection results chart."""
        if df.empty:
            return go.Figure().update_layout(title="No detection data available")
        
        # Extract detection columns
        detection_cols = [col for col in df.columns if col.startswith('detection_object_') and col.endswith('_class')]
        
        if not detection_cols:
            return go.Figure().update_layout(title="No detection data available")
            
        # Count occurrences of each object class
        objects = []
        for col in detection_cols:
            objects.extend(df[col].dropna().tolist())
        
        object_counts = pd.Series(objects).value_counts().reset_index()
        object_counts.columns = ['Object', 'Count']
        
        fig = px.bar(object_counts, x='Object', y='Count', title='Object Detection Results')
        return fig
    
    def _create_detections_list(self, df):
        """Create a list of recent detections."""
        if df.empty:
            return html.Div("No detection data available")
        
        # Get the 5 most recent image results
        recent_df = df.sort_values(by='metadata_timestamp', ascending=False).head(5)
        
        detections = []
        for _, row in recent_df.iterrows():
            # Get all object classes for this image
            detection_cols = [col for col in row.index if col.startswith('detection_object_') and col.endswith('_class')]
            object_classes = [row[col] for col in detection_cols if pd.notna(row[col])]
            
            if object_classes:
                detection_div = html.Div([
                    html.H4(f"Image: {row.get('metadata_image_id', 'Unknown')}"),
                    html.P(f"Detected objects: {', '.join(object_classes)}"),
                    html.Hr()
                ])
                detections.append(detection_div)
        
        if not detections:
            return html.Div("No detection data available")
            
        return html.Div(detections)
    
    def _create_volume_chart(self, text_df, image_df):
        """Create a chart showing processing volume over time."""
        if text_df.empty and image_df.empty:
            return go.Figure().update_layout(title="No data available")
        
        data = []
        
        # Process text data if available
        if not text_df.empty and 'metadata_timestamp' in text_df.columns:
            text_df['timestamp'] = pd.to_datetime(text_df['metadata_timestamp'], errors='coerce')
            text_df = text_df.dropna(subset=['timestamp'])
            if not text_df.empty:
                text_df['date'] = text_df['timestamp'].dt.date
                text_counts = text_df.groupby('date').size().reset_index()
                text_counts.columns = ['date', 'count']
                text_counts['type'] = 'Text'
                data.append(text_counts)
        
        # Process image data if available
        if not image_df.empty and 'metadata_timestamp' in image_df.columns:
            image_df['timestamp'] = pd.to_datetime(image_df['metadata_timestamp'], errors='coerce')
            image_df = image_df.dropna(subset=['timestamp'])
            if not image_df.empty:
                image_df['date'] = image_df['timestamp'].dt.date
                image_counts = image_df.groupby('date').size().reset_index()
                image_counts.columns = ['date', 'count']
                image_counts['type'] = 'Image'
                data.append(image_counts)
        
        if not data:
            return go.Figure().update_layout(title="No timestamp data available")
            
        # Combine the data
        df = pd.concat(data)
        
        fig = px.line(df, x='date', y='count', color='type', title='Processing Volume Over Time')
        return fig
    
    def _create_system_status(self):
        """Create a system status display."""
        try:
            # This is a placeholder for actual system monitoring
            # In a production environment, this would query system metrics
            
            status_items = [
                html.Div([
                    html.H4("Hadoop Cluster"),
                    html.P("Status: Running", style={'color': 'green'}),
                    html.P(f"Last checked: {time.strftime('%Y-%m-%d %H:%M:%S')}")
                ]),
                html.Div([
                    html.H4("Kafka"),
                    html.P("Status: Running", style={'color': 'green'}),
                    html.P(f"Last checked: {time.strftime('%Y-%m-%d %H:%M:%S')}")
                ]),
                html.Div([
                    html.H4("Spark"),
                    html.P("Status: Running", style={'color': 'green'}),
                    html.P(f"Last checked: {time.strftime('%Y-%m-%d %H:%M:%S')}")
                ]),
                html.Div([
                    html.H4("AI API"),
                    html.P("Status: Running", style={'color': 'green'}),
                    html.P(f"Last checked: {time.strftime('%Y-%m-%d %H:%M:%S')}")
                ])
            ]
            
            return html.Div(status_items)
        except Exception as e:
            logger.error(f"Failed to create system status: {str(e)}")
            return html.Div("System status unavailable")
    
    def run(self):
        """Run the Dash application."""
        logger.info(f"Starting dashboard on {DASHBOARD_HOST}:{DASHBOARD_PORT}")
        self.app.run_server(debug=False, host=DASHBOARD_HOST, port=DASHBOARD_PORT)
    
    def close(self):
        """Close all connections."""
        try:
            if self.connection:
                self.connection.close()
            logger.info("Connections closed")
        except Exception as e:
            logger.error(f"Error closing connections: {str(e)}")

if __name__ == "__main__":
    visualizer = DataVisualizer()
    try:
        visualizer.run()
    except KeyboardInterrupt:
        logger.info("Dashboard interrupted")
    finally:
        visualizer.close()

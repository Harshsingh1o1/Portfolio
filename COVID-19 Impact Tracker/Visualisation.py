import pandas as pd
import numpy as np
import matplotlib.pyplot as plt
import seaborn as sns
import folium
import plotly.express as px
import plotly.graph_objects as go
from plotly.subplots import make_subplots
from scipy import stats

# Assuming you've already run the SQL cleaning queries and exported the results

# Load the cleaned data
def load_data(file_path):
    """Load data from CSV files exported after SQL cleaning"""
    return pd.read_csv(file_path)

# Load the three main datasets
country_metrics = load_data('country_metrics.csv')
case_progression = load_data('case_progression.csv')
vaccination_impact = load_data('vaccination_impact.csv')

# Convert date columns to datetime
case_progression['date'] = pd.to_datetime(case_progression['date'])
vaccination_impact['reference_date'] = pd.to_datetime(vaccination_impact['reference_date'])

# 1. COVID-19 Spread Pattern Analysis
def visualize_global_trends():
    """Visualize global COVID-19 trends over time"""
    plt.figure(figsize=(14, 10))
    
    # Daily new cases and deaths
    plt.subplot(2, 1, 1)
    plt.plot(case_progression['date'], case_progression['daily_new_cases'], 'b-', label='Daily New Cases')
    plt.plot(case_progression['date'], case_progression['daily_new_deaths'], 'r-', label='Daily New Deaths')
    plt.title('Global COVID-19 Daily New Cases and Deaths')
    plt.xlabel('Date')
    plt.ylabel('Count')
    plt.legend()
    plt.grid(True, alpha=0.3)
    plt.xticks(rotation=45)
    
    # Cumulative cases and deaths
    plt.subplot(2, 1, 2)
    plt.plot(case_progression['date'], case_progression['cumulative_cases'], 'b-', label='Cumulative Cases')
    plt.plot(case_progression['date'], case_progression['cumulative_deaths'], 'r-', label='Cumulative Deaths')
    plt.title('Global COVID-19 Cumulative Cases and Deaths')
    plt.xlabel('Date')
    plt.ylabel('Count')
    plt.legend()
    plt.grid(True, alpha=0.3)
    plt.xticks(rotation=45)
    
    plt.tight_layout()
    plt.savefig('global_covid_trends.png', dpi=300)
    
    # Create an interactive time series with Plotly
    fig = make_subplots(specs=[[{"secondary_y": True}]])
    
    fig.add_trace(
        go.Scatter(x=case_progression['date'], y=case_progression['cumulative_cases'], 
                   name="Cumulative Cases", mode='lines', line=dict(color='blue')),
        secondary_y=False
    )
    
    fig.add_trace(
        go.Scatter(x=case_progression['date'], y=case_progression['cumulative_deaths'], 
                   name="Cumulative Deaths", mode='lines', line=dict(color='red')),
        secondary_y=True
    )
    
    fig.update_layout(
        title_text="Global Cumulative COVID-19 Cases and Deaths",
        xaxis_title="Date",
        legend=dict(
            orientation="h",
            yanchor="bottom",
            y=1.02,
            xanchor="right",
            x=1
        )
    )
    
    fig.update_yaxes(title_text="Cumulative Cases", secondary_y=False)
    fig.update_yaxes(title_text="Cumulative Deaths", secondary_y=True)
    
    fig.write_html('global_covid_interactive.html')

# 2. Vaccination Rate Impact Analysis
def analyze_vaccination_impact():
    """Analyze the impact of vaccination on case and mortality rates"""
    plt.figure(figsize=(16, 8))
    
    # Vaccination rate vs case rate
    plt.subplot(1, 2, 1)
    sns.regplot(x='vaccination_rate', y='case_rate', data=country_metrics, 
                scatter_kws={'alpha':0.5}, line_kws={'color':'red'})
    plt.title('Vaccination Rate vs Case Rate')
    plt.xlabel('Vaccination Rate (%)')
    plt.ylabel('Case Rate (%)')
    plt.grid(True, alpha=0.3)
    
    # Vaccination rate vs mortality rate
    plt.subplot(1, 2, 2)
    sns.regplot(x='vaccination_rate', y='mortality_rate', data=country_metrics, 
                scatter_kws={'alpha':0.5}, line_kws={'color':'red'})
    plt.title('Vaccination Rate vs Mortality Rate')
    plt.xlabel('Vaccination Rate (%)')
    plt.ylabel('Mortality Rate (%)')
    plt.grid(True, alpha=0.3)
    
    plt.tight_layout()
    plt.savefig('vaccination_impact.png', dpi=300)
    
    # Calculate statistical correlation
    vax_case_corr = stats.pearsonr(country_metrics['vaccination_rate'].fillna(0), 
                                   country_metrics['case_rate'].fillna(0))
    vax_death_corr = stats.pearsonr(country_metrics['vaccination_rate'].fillna(0), 
                                    country_metrics['mortality_rate'].fillna(0))
    
    print(f"Correlation between vaccination and case rates: {vax_case_corr[0]:.4f}, p-value: {vax_case_corr[1]:.4f}")
    print(f"Correlation between vaccination and mortality rates: {vax_death_corr[0]:.4f}, p-value: {vax_death_corr[1]:.4f}")
    
    # Create interactive visualization with Plotly
    fig = px.scatter(country_metrics, 
                     x="vaccination_rate", 
                     y="mortality_rate", 
                     size="population", 
                     color="case_rate",
                     hover_name="location", 
                     log_x=False, 
                     size_max=60,
                     title="COVID-19 Mortality Rate vs Vaccination Rate by Country")
    
    fig.update_layout(
        xaxis_title="Vaccination Rate (%)",
        yaxis_title="Mortality Rate (%)",
        coloraxis_colorbar_title="Case Rate (%)"
    )
    
    fig.write_html('vaccination_mortality_interactive.html')

# 3. Geographical Distribution Visualization
def create_geographical_visualizations():
    """Create visualizations showing the geographic distribution of COVID-19 metrics"""
    # Create world map of case rates with Folium
    world_map = folium.Map(location=[0, 0], zoom_start=2, tiles="CartoDB positron")
    
    # Add choropleth layer
    folium.Choropleth(
        geo_data='world_countries.json',  # You'll need this GeoJSON file
        name='choropleth',
        data=country_metrics,
        columns=['iso_code', 'case_rate'],
        key_on='feature.properties.ISO_A3',  # Make sure this matches your GeoJSON structure
        fill_color='YlOrRd',
        fill_opacity=0.7,
        line_opacity=0.2,
        legend_name='COVID-19 Case Rate (%)'
    ).add_to(world_map)
    
    # Save the map
    world_map.save('covid_world_map.html')
    
    # Create interactive global maps with Plotly
    fig_cases = px.choropleth(
        country_metrics, 
        locations="iso_code",
        color="case_rate", 
        hover_name="location", 
        color_continuous_scale=px.colors.sequential.Plasma,
        title="COVID-19 Case Rates by Country"
    )
    
    fig_cases.update_layout(coloraxis_colorbar=dict(title="Case Rate (%)"))
    fig_cases.write_html('case_rate_map.html')
    
    fig_mortality = px.choropleth(
        country_metrics, 
        locations="iso_code",
        color="mortality_rate", 
        hover_name="location", 
        color_continuous_scale=px.colors.sequential.Reds,
        title="COVID-19 Mortality Rates by Country"
    )
    
    fig_mortality.update_layout(coloraxis_colorbar=dict(title="Mortality Rate (%)"))
    fig_mortality.write_html('mortality_rate_map.html')
    
    fig_vax = px.choropleth(
        country_metrics, 
        locations="iso_code",
        color="vaccination_rate", 
        hover_name="location", 
        color_continuous_scale=px.colors.sequential.Blues,
        title="COVID-19 Vaccination Rates by Country"
    )
    
    fig_vax.update_layout(coloraxis_colorbar=dict(title="Vaccination Rate (%)"))
    fig_vax.write_html('vaccination_rate_map.html')

# 4. Additional Insights
def generate_additional_insights():
    """Create additional visualizations for deeper insights"""
    # Top 20 countries by case rate
    top_cases = country_metrics.nlargest(20, 'case_rate')
    plt.figure(figsize=(12, 10))
    sns.barplot(x='case_rate', y='location', data=top_cases, palette='viridis')
    plt.title('Top 20 Countries by COVID-19 Case Rate')
    plt.xlabel('Case Rate (%)')
    plt.ylabel('Country')
    plt.tight_layout()
    plt.savefig('top_countries_case_rate.png', dpi=300)
    
    # Top 20 countries by mortality rate
    top_mortality = country_metrics.nlargest(20, 'mortality_rate')
    plt.figure(figsize=(12, 10))
    sns.barplot(x='mortality_rate', y='location', data=top_mortality, palette='magma')
    plt.title('Top 20 Countries by COVID-19 Mortality Rate')
    plt.xlabel('Mortality Rate (%)')
    plt.ylabel('Country')
    plt.tight_layout()
    plt.savefig('top_countries_mortality_rate.png', dpi=300)
    
    # Create a scatter matrix to explore relationships between multiple variables
    cols_to_plot = ['case_rate', 'mortality_rate', 'vaccination_rate']
    scatter_matrix = pd.plotting.scatter_matrix(country_metrics[cols_to_plot], 
                                               figsize=(12, 12), 
                                               diagonal='kde', 
                                               alpha=0.5)
    plt.tight_layout()
    plt.savefig('covid_scatter_matrix.png', dpi=300)

# Execute all visualizations
if __name__ == "__main__":
    print("Generating COVID-19 visualizations...")
    visualize_global_trends()
    analyze_vaccination_impact()
    create_geographical_visualizations()
    generate_additional_insights()
    print("All visualizations complete!")

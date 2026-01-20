library(shiny)
library(tidyverse)
library(maps)
library(mapproj)
library(plotly)

# Load the data
data <- read.csv("data/state_level_results_births_only.csv")

ui <- fluidPage(
  tags$head(
    tags$style(HTML("
      .plotly {
        min-height: 500px !important;
      }
      
      @media (min-width: 769px) {
        .js-plotly-plot {
          height: 650px !important;
        }
      }
      
      @media (max-width: 768px) {
        .sidebar-layout {
          flex-direction: column !important;
        }
        .sidebar-panel {
          width: 100% !important;
          order: 2;
        }
        .main-panel {
          width: 100% !important;
          order: 1;
        }
        .js-plotly-plot {
          height: 400px !important;
        }
      }
    "))
  ),
  
  titlePanel("VaxImpactMap"),
  h4("Quantifying the Health and Economic Costs of Declining Childhood Vaccination", 
     style = "text-align: center; margin-top: -10px; margin-bottom: 20px; color: #555;"),
  
  sidebarLayout(
    sidebarPanel(
      width = 2,
      
      selectInput("disease",
                  "Disease:",
                  choices = unique(data$Disease),
                  selected = unique(data$Disease)[1]),
      
      sliderInput("percent_decline",
                  "Coverage Decline:",
                  min = min(data$Percent_Decline),
                  max = max(data$Percent_Decline),
                  value = 10,
                  step = 1,
                  post = "%"),
      
      selectInput("accrual_years",
                  "Years of lower coverage:",
                  choices = unique(data$Accrual_Label),
                  selected = unique(data$Accrual_Label)[1]),
      
      radioButtons("burden_type",
                   "Burden Type:",
                   choices = c("Additional" = "additional",
                               "Total" = "total"),
                   selected = "additional"),
      
      radioButtons("rate_or_count",
                   "Display:",
                   choices = c("Counts" = "count",
                               "Rates (per 100k)" = "rate"),
                   selected = "count"),
      
      hr(),
      actionButton("show_info", "About", icon = icon("info-circle"))
    ),
    
    mainPanel(
      width = 10,
      plotlyOutput("map", height = "700px"),
      
      # Mobile hint
      tags$p("Hover over any state for details. Best viewed on desktop.", 
             style = "text-align: center; color: #888; font-size: 12px; margin-top: 5px;"),
      
      div(style = "text-align: center; margin-top: 20px; margin-bottom: 20px;",
          img(src = "logo_emory_cidmath_dark_blue_2_no-tagline.svg", 
              height = "60px")
      ),
      
      hr(),
      
      div(style = "margin-top: 30px; padding: 20px; background-color: #f8f9fa; border-radius: 5px;",
          h3("Using VaxImpact"),
          h4("How to navigate the tool:"),
          tags$ol(
            tags$li("Select a vaccine-preventable disease from the dropdown menu"),
            tags$li("Hover over any state to view projected impacts specific to that location"),
            tags$li("Adjust the slider to model different magnitudes of coverage decline (e.g., 5%, 10%, 15% reduction)"),
            tags$li(HTML("Choose your outcome:
            <ul>
              <li><strong>Additional burden (default):</strong> Increase above current levels due to declining coverage</li>
              <li><strong>Total burden:</strong> Combined current and additional disease burden</li>
            </ul>")),
            tags$li(HTML("Choose your scale:
            <ul>
              <li><strong>Per capita (default):</strong> Results are normalized by the number of children at risk in each state (useful for comparing risk intensity across states)</li>
              <li><strong>Absolute numbers:</strong> Total projected cases, hospitalizations, and deaths (useful for understanding overall burden)</li>
            </ul>"))
          ),
          
          h3("Understanding the Metrics", style = "margin-top: 30px;"),
          tags$dl(
            tags$dt(strong("Additional cases")),
            tags$dd("The projected annual increase in children with the disease, resulting from reduced vaccination of newborns."),
            
            tags$dt(strong("Additional hospitalizations")),
            tags$dd("The number of additional cases severe enough to require inpatient hospital care."),
            
            tags$dt(strong("Additional deaths")),
            tags$dd("Estimated annual increase in deaths attributable to the disease, based on historical case-fatality rates."),
            
            tags$dt(strong("Additional days of work missed")),
            tags$dd("Projected increase in workdays lost annually as caregivers stay home to care for sick children."),
            
            tags$dt(strong("Additional economic costs")),
            tags$dd("Combined annual costs in US dollars, including direct medical expenses (hospitalizations, treatments) and indirect costs (lost productivity from missed work).")
          ),
          
          h3("Interpreting the Results", style = "margin-top: 30px;"),
          h4("What these projections represent:"),
          p("The estimates model the steady-state impact of sustained lower vaccination coverage—the annual disease burden expected once reduced immunization rates become established across the population. These are not outbreak scenarios or one-time events."),
          p("The model assumes coverage declines affect newborns beginning now, with impacts accumulating as these cohorts age through childhood. Results reflect long-term equilibrium conditions."),
          
          h4("Key considerations:"),
          tags$ul(
            tags$li("Even modest coverage declines (5-10%) can produce substantial increases in disease burden, particularly in populous states or those with higher birth rates"),
            tags$li("Geographic variation in existing coverage levels means some states face higher baseline risk than others"),
            tags$li("Declines are not evenly distributed—communities with lower vaccination rates experience disproportionate impacts"),
            tags$li("These projections use conservative assumptions; outbreaks could produce more severe short-term spikes")
          ),
          
          h3("Methodology", style = "margin-top: 30px;"),
          p("VaxImpactMap uses simple analytical epidemiological models calibrated to current state-level vaccination coverage, birth rates, and disease surveillance data. The models are based on the idea that declines in coverage will only affect new births. Older children who were vaccinated as babies retain the immunity conferred by immunization. Therefore, gaps in immunity take time to accrue."),
          p("Disease parameters (transmission rates, severity, case-fatality ratios) are derived from CDC surveillance, published literature, and historical outbreak data. Economic costs include direct medical expenses and indirect productivity losses, calculated using standard health economics methods."),
          p(HTML("For detailed technical documentation, including data sources, model equations, parameter values, and validation procedures, see: <strong>VaxImpactMap Technical Methods</strong>")),
          
          h3("Use Cases", style = "margin-top: 30px;"),
          p(strong("For public health departments:"), " Project disease resurgence in your state under different coverage scenarios to inform resource planning and intervention priorities."),
          p(strong("For journalists and media:"), " Access state-specific, evidence-based estimates to illustrate the concrete consequences of vaccine hesitancy for your audience."),
          p(strong("For advocacy organizations:"), " Use data-driven projections to demonstrate the importance of maintaining high vaccination coverage and to support policy recommendations.")
      )
    )
  )
)

server <- function(input, output, session) {
  
  # Show modal dialog on startup
  showModal(modalDialog(
    title = "Welcome to VaxImpactMap",
    HTML("
      <p>Childhood vaccination rates in the United States have declined in recent years. Growing confusion about vaccine safety and changes to public health guidance may accelerate these declines, putting more children at risk for preventable diseases.</p>
      
      <p>VaxImpactMap is an interactive tool that projects the real-world consequences of reduced vaccine coverage. Using epidemiological models and state-level data, it estimates the additional disease burden—cases, hospitalizations, deaths, missed workdays, and healthcare costs—that would result from specific declines in immunization coverage.</p>
      
      <p>This tool is designed for public health officials, policymakers, journalists, and parents who need evidence-based projections to inform decisions, communicate risks, and support vaccination programs.</p>
      
      <p><strong>Explore VaxImpactMap to see how coverage declines translate into health and economic impacts in your state.</strong></p>
    "),
    size = "l",
    easyClose = TRUE,
    footer = modalButton("Get Started")
  ))
  
  # Allow users to re-open the info dialog
  observeEvent(input$show_info, {
    showModal(modalDialog(
      title = "About VaxImpactMap",
      HTML("
        <p>Childhood vaccination rates in the United States have declined in recent years. Growing confusion about vaccine safety and changes to public health guidance may accelerate these declines, putting more children at risk for preventable diseases.</p>
        
        <p>VaxImpact is an interactive tool that projects the real-world consequences of reduced vaccine coverage. Using epidemiological models and state-level data, it estimates the additional disease burden—cases, hospitalizations, deaths, missed workdays, and healthcare costs—that would result from specific declines in immunization coverage.</p>
        
        <p>This tool is designed for public health officials, policymakers, journalists, and parents who need evidence-based projections to inform decisions, communicate risks, and support vaccination programs.</p>
        
        <p><strong>Explore VaxImpact to see how coverage declines translate into health and economic impacts in your state.</strong></p>
      "),
      size = "l",
      easyClose = TRUE,
      footer = modalButton("Close")
    ))
  })
  
  # Reactive expression to determine which column to use
  metric_column <- reactive({
    prefix <- if(input$burden_type == "additional") "Additional_" else ""
    base_metric <- paste0(prefix, "Hospitalizations_Count")
    
    if (input$burden_type == "total") {
      base_metric <- "Hospitalizations_Count"
    }
    
    if (input$rate_or_count == "rate") {
      base_metric <- if(input$burden_type == "additional") {
        "Additional_Hospitalizations_Count_per_100k"
      } else {
        "Hospitalizations_Count_per_100k"
      }
    }
    
    return(base_metric)
  })
  
  # Filter data based on inputs
  filtered_data <- reactive({
    data %>%
      filter(
        Disease == input$disease,
        Percent_Decline == input$percent_decline,
        Accrual_Label == input$accrual_years
      ) %>%
      mutate(state_lower = tolower(State))
  })
  
  # Render the map
  output$map <- renderPlotly({
    # Get map data
    states_map <- map_data("state")
    
    # Get filtered state data
    state_data <- filtered_data()
    
    # Join map with data
    plot_data <- states_map %>%
      left_join(state_data, by = c("region" = "state_lower"))
    
    # Get the metric value for coloring
    metric_col <- metric_column()
    
    # Create tooltip text
    plot_data <- plot_data %>%
      group_by(region) %>%
      mutate(
        tooltip_text = if(input$burden_type == "additional") {
          paste0(
            "<b style='font-size:16px;'>", toupper(tools::toTitleCase(region)), "</b><br>",
            "Baseline coverage: ", scales::percent(Baseline_Coverage, accuracy = 0.1), "<br>",
            "<br>",
            "<b>HEALTH BURDEN</b>", "<br>",
            "Additional Cases: ", scales::comma(Additional_Case_Count), "<br>",
            "Additional Hospitalizations: ", scales::comma(Additional_Hospitalizations_Count), "<br>",
            "Additional Deaths: ", round(Additional_Deaths_Count, 1), "<br>",
            "<br>",
            "<b>ECONOMIC BURDEN</b>", "<br>",
            "Additional Workdays Lost: ", scales::comma(Additional_Workdays_Lost), "<br>",
            "Additional Productivity Costs: ", scales::dollar(round(Additional_Productivity_Cost / 100000) * 100000), "<br>",
            "Additional Hospitalization Costs: ", scales::dollar(round(Additional_Hospitalization_Cost / 100000) * 100000), "<br>",
            "Additional Total Costs: ", scales::dollar(round(Additional_Total_Cost / 100000) * 100000)
          )
        } else {
          paste0(
            "<b style='font-size:16px;'>", toupper(tools::toTitleCase(region)), "</b><br>",
            "Baseline coverage: ", scales::percent(Baseline_Coverage, accuracy = 0.1), "<br>",
            "<br>",
            "Total Cases: ", scales::comma(Case_Count), "<br>",
            "Total Hospitalizations: ", scales::comma(Hospitalizations_Count), "<br>",
            "Total Deaths: ", round(Deaths_Count, 1)
          )
        }
      ) %>%
      ungroup()
    
    # Build legend title
    burden_label <- if(input$burden_type == "additional") "Additional " else "Total "
    rate_label <- if(input$rate_or_count == "rate") " per 100k" else ""
    legend_name <- paste0(burden_label, "Hospitalizations", rate_label)
    
    # Create the plot WITH ggplot legend
    p <- ggplot(plot_data, aes(x = long, y = lat, group = group)) +
      geom_polygon(
        aes(fill = .data[[metric_col]], text = tooltip_text), 
        color = "white", 
        size = 0.3
      ) +
      scale_fill_gradient(
        low = "#ffffcc", 
        high = "#800026",
        name = legend_name,
        labels = scales::comma
      ) +
      coord_map() +
      theme_void() +
      theme(legend.position = "none"
      ) +
      guides(fill = guide_colorbar(title.position = "top", title.hjust = 0.5))
    
    # Add title
    title_text <- paste("Annual", input$disease, "burden resulting from",
                        input$accrual_years, "of",
                        input$percent_decline,"% decline from current coverage")
    
    # Convert to plotly and force legend to bottom
    ggplotly(p, tooltip = "text") %>%
      layout(
        title = list(
          text = title_text,
          font = list(size = 14)
        ),
        hoverlabel = list(
          bgcolor = "white",
          font = list(family = "Arial", size = 12, color = "black")
        ),
        showlegend = FALSE,
        margin = list(t = 50, b = 10, l = 0, r = 0),
        autosize = TRUE
      ) %>%
      config(
        responsive = TRUE,
        displayModeBar = FALSE
      )
  })
}

shinyApp(ui, server)
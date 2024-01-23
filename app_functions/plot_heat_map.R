# Function to prepare data for heatmap
prepare_heatmap_data <- function(weightlifting_data, heatmap_metric = "Frequency", category="Push_Pull_Legs", time_bin = "2 months") {
  # Create time bins dynamically based on the time_bin argument
  time_breaks <- case_when(
    time_bin == "2 months" ~ "2 months",
    time_bin == "4 months" ~ "4 months",
    TRUE ~ "2 months" # default case
  )
  
  # Ensure heatmap_data is defined within this function scope
  heatmap_data <- weightlifting_data %>%
    mutate(time_bin = cut(date, breaks = time_bin))
  
  if (category=="exercise_name") {
    heatmap_data <- heatmap_data %>%
      group_by(time_bin, exercise_name)
  } else if (category=="Anterior_Posterior") {
    heatmap_data <- heatmap_data %>%
      group_by(time_bin, Anterior_Posterior)
  } else if (category=="Push_Pull_Legs") {
    heatmap_data <- heatmap_data %>%
      group_by(time_bin, Push_Pull_Legs)
  }

  heatmap_data <- heatmap_data %>%
    summarise(
      Frequency = n(),
      Volume = sum(one_rep_max, na.rm = TRUE),
      .groups = 'drop' # This ensures ungrouping after summarisation
    )

  # Depending on the metric, select the appropriate columns
  heatmap_data <- if (heatmap_metric == "Frequency") {
    heatmap_data %>%
      select(-Volume)
  } else {
    heatmap_data %>%
      select(-Frequency)
  }

  return(heatmap_data) # Make sure to return the heatmap_data
}

get_breaks_labels <- function(metric, category, time_bin) {
  if (metric == "Frequency") {
    if (time_bin == "2 months") {
      if (category == "Push_Pull_Legs") {
        return(list(breaks = c(0, 30, 100, 300, Inf),
                    labels = c("0-30", "30-100", "100-300", "300+")))
      } else if (category == "Anterior_Posterior") {
        return(list(breaks = c(0, 30, 100, 300, Inf),
                    labels = c("0-30", "30-100", "100-300", "300+")))
      } else {
        return(list(breaks = c(0, 3, 10, 30, 100, Inf),
                    labels = c("0-3", "3-10", "10-30", "30-100", "100+")))
      }
    } else if (time_bin == "4 months") {
      if (category == "Push_Pull_Legs") {
        return(list(breaks = c(0, 100, 300, 1000, Inf),
                    labels = c("0-100", "100-300", "300-1000", "1000+")))
      } else if (category == "Anterior_Posterior") {
        return(list(breaks = c(0, 100, 300, 1000, Inf),
                    labels = c("0-100", "100-300", "300-1000", "1000+")))
      } else {
        return(list(breaks = c(0, 3, 10, 30, 100, Inf),
                    labels = c("0-3", "3-10", "10-30", "30-100", "100+")))
      }
    }
  } else if (metric == "Volume") {
    if (time_bin == "2 months") {
      if (category == "Push_Pull_Legs") {
        return(list(breaks = c(0, 3000, 10000, 30000, 100000, Inf),
                    labels = c("0-3000", "3000-10000", "10000-30000", "30000-100000", "100000+")))
      } else if (category == "Anterior_Posterior") {
        return(list(breaks = c(0, 3000, 10000, 30000, 100000, Inf),
                    labels = c("0-3000", "3000-10000", "10000-30000", "30000-100000", "100000+")))
      } else {
        return(list(breaks = c(0, 300, 1000, 3000, 10000, Inf),
                    labels = c("0-300", "300-1000", "1000-3000", "3000-10000", "10000+")))
      }
    } else if (time_bin == "4 months") {
      if (category == "Push_Pull_Legs") {
        return(list(breaks = c(0, 10000, 30000, 100000, Inf),
                    labels = c("0-10000", "10000-30000", "30000-100000", "100000+")))
      } else if (category == "Anterior_Posterior") {
        return(list(breaks = c(0, 10000, 30000, 100000, Inf),
                    labels = c("0-10000", "10000-30000", "30000-100000", "100000+")))
      } else {
        return(list(breaks = c(0, 1000, 3000, 10000, 30000, Inf),
                    labels = c("0-1000", "1000-3000", "3000-10000", "10000-30000", "30000+")))
      }
    }
  }
}


# Function to get the top exercises and order them
get_top_exercises_ordered <- function(heatmap_data) {
  top_exercises <- heatmap_data %>%
    count(exercise_name) %>%
    top_n(10, n) %>%
    pull(exercise_name)

  heatmap_data <- heatmap_data %>%
    filter(exercise_name %in% top_exercises) %>%
    mutate(
      exercise_name = factor(exercise_name, levels = top_exercises)#,
      #Push_Pull_Legs = factor(Push_Pull_Legs, levels = c("push", "pull", "legs"))
    ) %>%
    arrange(
      #Push_Pull_Legs, 
      exercise_name
    )

  return(heatmap_data)
}


# Function to plot heatmap
plot_heatmap <- function(heatmap_data, heatmap_metric = "Frequency", category = "exercise_name", time_bin) {
  # Filter out "Unclear" labels
  heatmap_data <- heatmap_data %>%
    filter(!get(category) %in% c("Unclear", "unclear") & !is.na(get(category)))

  if (category == "exercise_name") {
    heatmap_data <- get_top_exercises_ordered(heatmap_data)
  }

  # Ensure time_bin is a Date
  heatmap_data$time_bin <- as.Date(heatmap_data$time_bin)
  
  # Capitalize only the first letter of each word
  heatmap_data[[category]] <- stringr::str_to_title(heatmap_data[[category]])

  # Define breaks for discretized buckets and assign labels
  breaks_labels <- get_breaks_labels(heatmap_metric, category, time_bin)
  breaks <- breaks_labels$breaks
  labels <- breaks_labels$labels
  heatmap_data$bucket <- cut(
    heatmap_data[[heatmap_metric]], breaks = breaks, labels = labels, include.lowest = TRUE
    )
  
  if (category == "exercise_name") {
    aspect_ratio <- 1.5
  } else {
    aspect_ratio <- 0.5
  }

  # Prepare the plot
  p <- ggplot(heatmap_data, aes(x = time_bin, y = forcats::fct_reorder(.f = as.factor(get(category)), .x = get(heatmap_metric)), fill = bucket)) +
    geom_tile() +
    scale_fill_manual(values = colorRampPalette(c("white", "#FF8C00"))(length(breaks) - 1)) +
    scale_x_date(date_minor_breaks = "1 month", date_labels = "%b %Y") +
    labs(x = "Date", y = NULL, fill = heatmap_metric) +
    theme_minimal(base_size = 18) +  # Increase the base text size
    theme(
      axis.text.x = element_text(angle = 90, hjust = 1, size = rel(1.2)),
      axis.text.y = element_text(size = rel(1.2)),
      legend.position = "bottom",
      legend.text = element_text(size = rel(1.1)),
      axis.ticks.y = element_blank(),
      panel.grid.major = element_blank(),
      panel.grid.minor = element_blank(),
      aspect.ratio = aspect_ratio  # Adjust aspect ratio to reduce tile height
    ) +
    guides(fill = guide_legend(nrow = 1, byrow = TRUE))  # Control the legend layout

  return(p)
}

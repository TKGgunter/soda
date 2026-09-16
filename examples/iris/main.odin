package iris_example

/*
   The iris dataset is a classic dataset often used to introduce students to
   data science and the tools of data science. What then is a better dataset
   can be used as an introduction to SODA. 

   The analysis executed in this program follows an introductory assignment
   constructed by Bill Mongan.

   The assignment can be found here: https://www.billmongan.com/Ursinus-CS173/Assignments/Iris
*/

import soda "../../"
import "core:fmt"
import "core:math"
import "core:os"

Data :: soda.Data
get_column :: soda.get_columnslice
head :: soda.head

main :: proc() {

    // By default 
    soda.init_formatter()

		data, success := os.read_entire_file("iris.csv", context.allocator)
    defer delete(data, context.allocator)
    df, _ := soda.parse_csv(string(data))

    // Lets print the first 5 rows of data.
    head(df)

    // Get a list of the unique flower names
    species, _ := get_column(df, "species")
    unique_species := soda.unique(species)
    fmt.println(unique_species)

    calc_euclidean_distance :: proc(vars: []Data, constants: []Data) -> f64 {
        pl := vars[0].(f64)
        pl_mean := constants[0].(f64)

        pw := vars[1].(f64)
        pw_mean := constants[1].(f64)

        sl := vars[2].(f64)
        sl_mean := constants[2].(f64)

        sw := vars[3].(f64)
        sw_mean := constants[3].(f64)

        return  math.sqrt(math.pow(pl - pl_mean, 2) + math.pow(pw - pw_mean, 2) + math.pow(sl - sl_mean, 2) + math.pow(sw - sw_mean, 2))
    }


    // Report species specific statistics
    report := make(map[string][dynamic]Data)
    report["sepal_width"] = make([dynamic]Data)
    report["sepal_length"] = make([dynamic]Data)
    report["petal_width"] = make([dynamic]Data)
    report["petal_length"] = make([dynamic]Data)
    report["distance"] = make([dynamic]Data)
    report["species"] = make([dynamic]Data)
    for species in unique_species.([]string) {

        species_df, _ := soda.filter(&df, {"species", .Eq, Data(species)}, context.temp_allocator)

        sw_mean, _ := soda.calc_to_scalar(species_df, soda.mean, "sepal_width")
        sl_mean, _ := soda.calc_to_scalar(species_df, soda.mean, "sepal_length")
        pw_mean, _ := soda.calc_to_scalar(species_df, soda.mean, "petal_width")
        pl_mean, _ := soda.calc_to_scalar(species_df, soda.mean, "petal_length")

        species_distance, _ := soda.calc_to_column(
            species_df, 
            calc_euclidean_distance, 
            []string{"sepal_width", "sepal_length", "petal_width", "petal_length"},
            []Data{sw_mean, sl_mean, pw_mean, pl_mean}
        )

        species_distance_mean, _ := soda.mean(species_distance)

        append(&report["sepal_width"], sw_mean)
        append(&report["sepal_length"], sl_mean)
        append(&report["petal_width"], pw_mean)
        append(&report["petal_length"], pl_mean)
        append(&report["distance"], species_distance_mean)
        append(&report["species"], species)

    }
    free_all(context.temp_allocator)
    
    fmt.println("Per Species Report")
    for k, v in report {
        fmt.printfln("%s %v", k, v)
    }

    // Lets classify assuming we do not know the species before hand
    // TODO: calc the euclidian distance for a point of our choosing
    sw_mean, _ := soda.calc_to_scalar(df, soda.mean, "sepal_width")
    sl_mean, _ := soda.calc_to_scalar(df, soda.mean, "sepal_length")
    pw_mean, _ := soda.calc_to_scalar(df, soda.mean, "petal_width")
    pl_mean, _ := soda.calc_to_scalar(df, soda.mean, "petal_length")

    distance, _ := soda.calc_to_column(
        df, 
        calc_euclidean_distance, 
        []string{"sepal_width", "sepal_length", "petal_width", "petal_length"},
        []Data{sw_mean, sl_mean, pw_mean, pl_mean}
    )

    soda.append_column(&df, "distance", distance)

    plot := soda.init_plot(&df)
    defer soda.delete_plot(plot)
    soda.add_mapping(&plot, soda.Aesthetic{x = "petal_length", y = "petal_width"})
    soda.add_scatter(&plot, size = 1.5)
    plot.labels.title = "Iris"

    /* Plotting with SODA is still in the works
    scatter := Plot(^DataFrame) {
        dataframe = &df,
        mapping   = Aesthetic{x = "sepal_length", y = "sepal_width"},
        labels    = Labels{title = "Iris: Sepal Length vs Sepal Width", x = "Sepal Length", y = "Sepal Width"},
    }
    append(&scatter.layers, Layer{geom = Point{size = 1.0, alpha = 1.0}})

    if plot_bytes, plot_ok := draw(scatter, .Svg); plot_ok {
        defer delete(plot_bytes)
        if err := os.write_entire_file("iris_scatter.svg", plot_bytes); err == nil {
            fmt.println("wrote iris_scatter.svg")
        } else {
            fmt.eprintln("failed to write iris_scatter.svg:", err)
        }
    } else {
        fmt.eprintln("failed to render scatter plot")
    }
    */
}

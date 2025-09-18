import Foundation
import FoundationModels

struct WeatherRequest: Encodable {
    let latitude: Float64
    let longitude: Float64
}

struct WeatherResponse: Decodable {
    let city: String
    let state: String
    let periods: [Period]
}

struct Period: Decodable {
    let number: Int
    let name: String
    let detailedForecast: String
}

struct WeatherTool: Tool {
    let name = "weatherService"
    let description = "Provides weather forecasts for the US."
    
    @Generable
    struct Arguments {
        @Guide(description: "The latitude of the location.")
        var latitude: Double
        @Guide(description: "The longitude of the location.")
        var longitude: Double
    }

    @Generable
    struct Reply {
        let periods: [Period]
    }

    @Generable
    struct Period {
        let name: String
        let forecast: String
    }
    
    func call(arguments: Arguments) async throws -> Reply {
        print("getting forecast for \(arguments.latitude), \(arguments.longitude)")
        let url = URL(string: "https://arax.ee/weather/forecast")!
        var request = URLRequest(url: url)
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpMethod = "POST"
        request.httpBody = try JSONEncoder().encode(WeatherRequest(latitude: arguments.latitude, longitude: arguments.longitude))
        let (data, _) = try await URLSession.shared.data(for: request)
        let response = try JSONDecoder().decode(WeatherResponse.self, from: data)
        print("got forecast for location: \(response.city)/\(response.state)")
        var periods = [Period]()
        for i in 0..<response.periods.count {
            let period = response.periods[i]
            periods.append(Period(name: period.name, forecast: period.detailedForecast))
            if i == 4 { break }
        }
        return Reply(periods: periods)
    }
}

func main() {
    let model = SystemLanguageModel.default
    if !model.isAvailable {
        print("model not available")
        return
    }
    let session = LanguageModelSession(model: model, tools: [WeatherTool()], instructions: "Provides weather forecasts for the US.")
    let semaphore = DispatchSemaphore(value: 0)
    Task {
        do {
            let response = try await session.respond(to: "What is the weather forecast for Columbus, Ohio?", options: GenerationOptions(temperature: 1.0))
            print("output: \(response.content)")
            // for try await partial in session.streamResponse(to: "What is the weather forecast for Columbus, Ohio?", options: GenerationOptions(temperature: 1.0)) {
            //     print(partial.content)
            // }
            // print("==========")
            // print(session.transcript.count)
            // for entry in session.transcript {
            //     print(entry)
            // }
        } catch LanguageModelSession.GenerationError.exceededContextWindowSize {
            print("error: exceeded context window size")
        } catch LanguageModelSession.GenerationError.unsupportedLanguageOrLocale {
            print("error: unsupported language or locale")
        } catch {
            print("error: \(error.localizedDescription)")
        }
        semaphore.signal()
    }
    semaphore.wait()
}

main()
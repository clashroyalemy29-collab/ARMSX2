import Perception
import Foundation

@Perceptible
final class Model {
    var count = 0
}

let model = Model()
model.count += 1
print(model.count)

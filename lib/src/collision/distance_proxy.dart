// Copyright 2012 Google Inc. All Rights Reserved.
// 
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
// 
//     http://www.apache.org/licenses/LICENSE-2.0
// 
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.
/**
 * A distance proxy is used by the GJK algorithm. It encapsulates any shape.
 */

part of box2d;

class DistanceProxy {
  final List<Vector2> vertices =
    new List<Vector2>.generate(
      Settings.MAX_POLYGON_VERTICES,
      (_) => new Vector2.zero(),
      growable: false);

  int count = 0;
  double radius = 0.0;

  /**
   * Constructs a new DistanceProxy.
   */
  DistanceProxy();

  /**
   * Initialize the proxy using the given shape. The shape
   * must remain in scope while the proxy is in use.
   */
  void setFromShape(shape) {
    // If the shape is a circle...
    if (shape.type == ShapeType.CIRCLE) {
      vertices[0].setFrom(shape.position);
      count = 1;
      radius = shape.radius;

      // If the shape is a polygon...
    } else if (shape.type == ShapeType.POLYGON) {
      count = shape.vertexCount;
      radius = shape.radius;
      for(int i = 0; i < count; i++) {
        vertices[i].setFrom(shape.vertices[i]);
      }
    } else {
      // Should always be a circle or a polygon.
      assert(false);
    }
  }

  /**
   * Get the supporting vertex index in the given direction.
   */
  int getSupport(Vector2 direction) {
    int bestIndex = 0;
    double bestValue = vertices[0].dot(direction);
    for (int i = 1; i < count; ++i) {
      double value = vertices[i].dot(direction);
      if(value > bestValue) {
        bestIndex = i;
        bestValue = value;
      }
    }

    return bestIndex;
  }

  /**
   * Get the supporting vertex in the given direction.
   */
  Vector2 getSupportVertex(Vector2 direction) => vertices[getSupport(direction)];
}

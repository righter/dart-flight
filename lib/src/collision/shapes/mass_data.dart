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

/** This holds the mass data computed for a shape. */

part of box2d;

class MassData {
  /** The mass of the shape, usually in kilograms. */
  double mass = 0.0;

  /** The position of the shape's centroid relative to the shape's origin. */
  Vector2 center = new Vector2.zero();

  /** The rotational inertia of the shape about the local origin. */
  double inertia = 0.0;

  /**
   * Constructs a blank mass data.
   */
  MassData();

  /**
   * Copies from the given mass data.
   */
  MassData.copy(MassData md) :
    mass = md.mass,
    inertia = md.inertia,
    center = new Vector2.copy(md.center);

  /**
   * Sets this mass data equal to the given mass data.
   */
  void setFrom(MassData md) {
    mass = md.mass;
    inertia = md.inertia;
    center.setFrom(md.center);
  }
}

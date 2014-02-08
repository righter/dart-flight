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

part of box2d;

class Sweep {
  /** Local center of mass position. */
  final Vector2 localCenter;

  /** Center world positions. */
  final Vector2 centerZero;
  final Vector2 center;

  /** World angles. */
  double angleZero = 0.0;
  double angle = 0.0;

  /**
   * Constructs a new Sweep with centers initialized to the origin and angles
   * set to zero.
   */
  Sweep()
      : localCenter = new Vector2.zero(),
        centerZero = new Vector2.zero(),
        center = new Vector2.zero();

  /**
   * Constructs a new sweep that is a copy of the given Sweep.
   */
  Sweep.copy(Sweep other)
      : localCenter = new Vector2.copy(other.localCenter),
        centerZero = new Vector2.copy(other.centerZero),
        center = new Vector2.copy(other.center),
        angleZero = other.angleZero,
        angle = other.angle;

  /**
   * Returns true if given object is equal to this sweep. Two sweeps are equal
   * if their fields are equal.
   */
  bool operator ==(other) {
    return localCenter == other.localCenter && centerZero == other.centerZero
        && center == other.center && angleZero == other.angleZero &&
        angle == other.angle;
  }

  int get hashCode {
    int result = 17;
    result = 37 * result + localCenter.x.hashCode;
    result = 37 * result + localCenter.y.hashCode;
    result = 37 * result + centerZero.x.hashCode;
    result = 37 * result + centerZero.y.hashCode;
    result = 37 * result + center.x.hashCode;
    result = 37 * result + center.y.hashCode;
    result = 37 * result + angleZero.hashCode;
    result = 37 * result + angle.hashCode;
    return result;
  }

  /**
   * Sets this Sweep equal to the given Sweep.
   */
  void setFrom(Sweep other) {
    localCenter.setFrom(other.localCenter);
    centerZero.setFrom(other.centerZero);
    center.setFrom(other.center);
    angleZero = other.angleZero;
    angle = other.angle;
  }

  void normalize() {
    double d = MathBox.TWO_PI * (angleZero / MathBox.TWO_PI).floorToDouble();
    angleZero -= d;
    angle -= d;
  }

  /**
   * Computes the interpolated transform at a specific time.
   * Time is the normalized time in [0,1].
   */
  void getTransform(Transform xf, double alpha) {
    assert (xf != null);

    xf.position.x = (1.0 - alpha) * centerZero.x + alpha * center.x;
    xf.position.y = (1.0 - alpha) * centerZero.y + alpha * center.y;
    xf.rotation.setRotation((1.0 - alpha) * angleZero + alpha * angle);

    // Shift to origin
    xf.position.x -= xf.rotation.entry(0,0) * localCenter.x + xf.rotation.entry(0,1)
        * localCenter.y;
    xf.position.y -= xf.rotation.entry(1,0) * localCenter.x + xf.rotation.entry(1,1)
        * localCenter.y;
  }

  /**
   * Advances the sweep forward, resulting in a new initial state.
   * Time is the new initial time.
   */
  void advance(double time) {
    centerZero.x = (1 - time) * centerZero.x + time * center.x;
    centerZero.y = (1 - time) * centerZero.y + time * center.y;
    angleZero = (1 - time) * angleZero + time * angle;
  }
}

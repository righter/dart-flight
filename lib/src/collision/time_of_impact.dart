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
 * Class used for computing the time of impact. This class should not be
 * constructed usually, just retrieve from the SingletonPool.getTimeOfImpact().
 */

part of box2d;

class TimeOfImpact {
  static const int MAX_ITERATIONS = 1000;

  static int toiCalls = 0;
  static int toiIters = 0;
  static int toiMaxIters = 0;
  static int toiRootIters = 0;
  static int toiMaxRootIters = 0;

  /** Pool variables */
  final SimplexCache cache = new SimplexCache();
  final DistanceInput distanceInput = new DistanceInput();
  final Transform xfA = new Transform();
  final Transform xfB = new Transform();
  final DistanceOutput distanceOutput = new DistanceOutput();
  final SeparationFunction fcn = new SeparationFunction();
  final List<int> indexes =
    new List<int>.generate(2, (_) => 0, growable: false);
  final Sweep sweepA = new Sweep();
  final Sweep sweepB = new Sweep();

  DefaultWorldPool pool;

  TimeOfImpact._construct(this.pool);

  /**
   * Compute the upper bound on time before two shapes penetrate. Time is
   * represented as a fraction between [0,tMax]. This uses a swept separating
   * axis and may miss some intermediate, non-tunneling collision. If you
   * change the time interval, you should call this function again.
   * Note: use Distance to compute the contact point and normal at the time
   * of impact.
   */
  void timeOfImpact(TimeOfImpactOutput output, TimeOfImpactInput input) {
    // CCD via the local separating axis method. This seeks progression
    // by computing the largest time at which separation is maintained.
    ++toiCalls;

    output.state = TimeOfImpactOutputState.UNKNOWN;
    output.t = input.tMax;

    DistanceProxy proxyA = input.proxyA;
    DistanceProxy proxyB = input.proxyB;

    sweepA.setFrom(input.sweepA);
    sweepB.setFrom(input.sweepB);

    // Large rotations can make the root finder fail, so we normalize the
    // sweep angles.
    sweepA.normalize();
    sweepB.normalize();

    double tMax = input.tMax;

    double totalRadius = proxyA.radius + proxyB.radius;
    double target = Math.max(Settings.LINEAR_SLOP,
        totalRadius - 3.0 * Settings.LINEAR_SLOP);
    double tolerance = 0.25 * Settings.LINEAR_SLOP;

    assert (target > tolerance);

    double t1 = 0.0;
    int iter = 0;

    cache.count = 0;
    distanceInput.proxyA = input.proxyA;
    distanceInput.proxyB = input.proxyB;
    distanceInput.useRadii = false;

    // The outer loop progressively attempts to compute new separating axes.
    // This loop terminates when an axis is repeated (no progress is made).
    while (true) {
      sweepA.getTransform(xfA, t1);
      sweepB.getTransform(xfB, t1);
      // Get the distance between shapes. We can also use the results
      // to get a separating axis
      distanceInput.transformA = xfA;
      distanceInput.transformB = xfB;
      pool.distance.distance(distanceOutput, cache, distanceInput);

      // If the shapes are overlapped, we give up on continuous collision.
      if (distanceOutput.distance <= 0) {
        // Failure!
        output.state = TimeOfImpactOutputState.OVERLAPPED;
        output.t = 0.0;
        break;
      }

      if (distanceOutput.distance < target + tolerance) {
        // Victory!
        output.state = TimeOfImpactOutputState.TOUCHING;
        output.t = t1;
        break;
      }

      // Initialize the separating axis.
      fcn.initialize(cache, proxyA, sweepA, proxyB, sweepB, t1);

      // Compute the TimeOfImpact on the separating axis. We do this by successively
      // resolving the deepest point. This loop is bounded by the number of
      // vertices.
      bool done = false;
      double t2 = tMax;
      int pushBackIter = 0;
      while (true) {

        // Find the deepest point at t2. Store the witness point indices.
        double s2 = fcn.findMinSeparation(indexes, t2);
        // Is the configuration separated?
        if (s2 > target + tolerance) {
          // Victory!
          output.state = TimeOfImpactOutputState.SEPARATED;
          output.t = tMax;
          done = true;
          break;
        }

        // Has the separation reached tolerance?
        if (s2 > target - tolerance) {
          // Advance the sweeps
          t1 = t2;
          break;
        }

        // Compute the initial separation of the witness points.
        double s1 = fcn.evaluate(indexes[0], indexes[1], t1);
        // Check for initial overlap. This might happen if the root finder
        // runs out of iterations.
        if (s1 < target - tolerance) {
          output.state = TimeOfImpactOutputState.FAILED;
          output.t = t1;
          done = true;
          break;
        }

        // Check for touching
        if (s1 <= target + tolerance) {
          // Victory! t1 should hold the TimeOfImpact (could be 0.0).
          output.state = TimeOfImpactOutputState.TOUCHING;
          output.t = t1;
          done = true;
          break;
        }

        // Compute 1D root of: f(x) - target = 0
        int rootIterCount = 0;
        double a1 = t1, a2 = t2;
        while (true) {
          // Use a mix of the secant rule and bisection.
          double t;
          if ((rootIterCount & 1) == 1) {
            // Secant rule to improve convergence.
            t = a1 + (target - s1) * (a2 - a1) / (s2 - s1);
          } else {
            // Bisection to guarantee progress.
            t = 0.5 * (a1 + a2);
          }

          double s = fcn.evaluate(indexes[0], indexes[1], t);

          if ((s - target).abs() < tolerance) {
            // t2 holds a tentative value for t1
            t2 = t;
            break;
          }

          // Ensure we continue to bracket the root.
          if (s > target) {
            a1 = t;
            s1 = s;
          } else {
            a2 = t;
            s2 = s;
          }

          ++rootIterCount;
          ++toiRootIters;

          // djm: whats with this? put in settings?
          if (rootIterCount == 50) {
            break;
          }
        }

        toiMaxRootIters = Math.max(toiMaxRootIters, rootIterCount);

        ++pushBackIter;

        if (pushBackIter == Settings.MAX_POLYGON_VERTICES) {
          break;
        }
      }

      ++iter;
      ++toiIters;

      if (done)
        break;

      if (iter == MAX_ITERATIONS) {
        // Root finder got stuck. Semi-victory.
        output.state = TimeOfImpactOutputState.FAILED;
        output.t = t1;
        break;
      }
    }

    toiMaxIters = Math.max(toiMaxIters, iter);
  }
}

class SeparationFunction {
  DistanceProxy proxyA = new DistanceProxy();
  DistanceProxy proxyB = new DistanceProxy();
  int type = SeparationType.POINTS;
  final Vector2 localPoint = new Vector2.zero();
  final Vector2 axis = new Vector2.zero();
  Sweep sweepA = new Sweep();
  Sweep sweepB = new Sweep();

  /** Pooling */
  final Vector2 localPointA = new Vector2.zero();
  final Vector2 localPointB = new Vector2.zero();
  final Vector2 pointA = new Vector2.zero();
  final Vector2 pointB = new Vector2.zero();
  final Vector2 localPointA1 = new Vector2.zero();
  final Vector2 localPointA2 = new Vector2.zero();
  final Vector2 normal = new Vector2.zero();
  final Vector2 localPointB1 = new Vector2.zero();
  final Vector2 localPointB2 = new Vector2.zero();
  final Vector2 axisA = new Vector2.zero();
  final Vector2 axisB = new Vector2.zero();
  final Vector2 temp = new Vector2.zero();
  final Transform xfa = new Transform();
  final Transform xfb = new Transform();

  SeparationFunction();

  double initialize(SimplexCache cache, DistanceProxy argProxyA, Sweep
      argSweepA, DistanceProxy argProxyB, Sweep argSweepB, double t1) {
    proxyA = argProxyA;
    proxyB = argProxyB;
    int count = cache.count;
    assert (0 < count && count < 3);

    sweepA = argSweepA;
    sweepB = argSweepB;

    sweepA.getTransform(xfa, t1);
    sweepB.getTransform(xfb, t1);

    if (count == 1) {
      type = SeparationType.POINTS;
      localPointA.setFrom(proxyA.vertices[cache.indexA[0]]);
      localPointB.setFrom(proxyB.vertices[cache.indexB[0]]);
      Transform.mulToOut(xfa, localPointA, pointA);
      Transform.mulToOut(xfb, localPointB, pointB);
      axis.setFrom(pointB).sub(pointA);
      double s = axis.normalizeLength();
      return s;
    } else if (cache.indexA[0] == cache.indexA[1]) {
      // Two points on B and one on A.
      type = SeparationType.FACE_B;

      localPointB1.setFrom(proxyB.vertices[cache.indexB[0]]);
      localPointB2.setFrom(proxyB.vertices[cache.indexB[1]]);

      temp.setFrom(localPointB2).sub(localPointB1);
      temp.scaleOrthogonalInto(-1.0, axis);
      axis.normalize();

      xfb.rotation.transformed(axis, normal);

      localPoint.setFrom(localPointB1);
      localPoint.add(localPointB2);
      localPoint.scale(.5);
      Transform.mulToOut(xfb, localPoint, pointB);

      localPointA.setFrom(proxyA.vertices[cache.indexA[0]]);
      Transform.mulToOut(xfa, localPointA, pointA);

      temp.setFrom(pointA);
      temp.sub(pointB);
      double s = temp.dot(normal);
      if (s < 0.0) {
        axis.negate();
        s = -s;
      }

      return s;
    } else {
      // Two points on A and one or two points on B.
      type = SeparationType.FACE_A;

      localPointA1.setFrom(proxyA.vertices[cache.indexA[0]]);
      localPointA2.setFrom(proxyA.vertices[cache.indexA[1]]);

      temp.setFrom(localPointA2);
      temp.sub(localPointA1);
      temp.scaleOrthogonalInto(-1.0, axis);
      axis.normalize();

      xfa.rotation.transformed(axis, normal);

      localPoint.setFrom(localPointA1);
      localPoint.add(localPointA2);
      localPoint.scale(.5);
      Transform.mulToOut(xfa, localPoint, pointA);

      localPointB.setFrom(proxyB.vertices[cache.indexB[0]]);
      Transform.mulToOut(xfb, localPointB, pointB);

      temp.setFrom(pointB);
      temp.sub(pointA);
      double s = temp.dot(normal);
      if (s < 0.0) {
        axis.negate();
        s = -s;
      }
      return s;
    }
  }

  double findMinSeparation(List<int> indexes, double t) {
    sweepA.getTransform(xfa, t);
    sweepB.getTransform(xfb, t);

    switch (type) {
      case SeparationType.POINTS:
        xfa.rotation.transposed().transformed(axis, axisA);
        xfb.rotation.transposed().transformed(axis.negate(),
            axisB);
        axis.negate();

        indexes[0] = proxyA.getSupport(axisA);
        indexes[1] = proxyB.getSupport(axisB);

        localPointA.setFrom(proxyA.vertices[indexes[0]]);
        localPointB.setFrom(proxyB.vertices[indexes[1]]);

        Transform.mulToOut(xfa, localPointA, pointA);
        Transform.mulToOut(xfb, localPointB, pointB);

        double separation = pointB.sub(pointA).dot(axis);
        return separation;

      case SeparationType.FACE_A:
        xfa.rotation.transformed(axis, normal);
        Transform.mulToOut(xfa, localPoint, pointA);

        normal.negate();
        xfb.rotation.transposed().transformed(normal, axisB);
        normal.negate();

        indexes[0] = -1;
        indexes[1] = proxyB.getSupport(axisB);

        localPointB.setFrom(proxyB.vertices[indexes[1]]);
        Transform.mulToOut(xfb, localPointB, pointB);

        double separation = pointB.sub(pointA).dot(normal);
        return separation;

      case SeparationType.FACE_B:
        xfb.rotation.transformed(axis, normal);
        Transform.mulToOut(xfb, localPoint, pointB);

        xfa.rotation.transposed().transformed(
            normal.negate(), axisA);
        normal.negate();

        indexes[1] = -1;
        indexes[0] = proxyA.getSupport(axisA);

        localPointA.setFrom(proxyA.vertices[indexes[0]]);
        Transform.mulToOut(xfa, localPointA, pointA);

        double separation = pointA.sub(pointB).dot(normal);
        return separation;

      default:
        assert (false);
        indexes[0] = -1;
        indexes[1] = -1;
        return 0.0;
    }
  }

  double evaluate(int indexA, int indexB, double t) {
    sweepA.getTransform(xfa, t);
    sweepB.getTransform(xfb, t);

    switch (type) {
      case SeparationType.POINTS:
        xfa.rotation.transposed().transformed(axis, axisA);
        xfb.rotation.transposed().transformed(axis.negate(),
            axisB);
        axis.negate();

        localPointA.setFrom(proxyA.vertices[indexA]);
        localPointB.setFrom(proxyB.vertices[indexB]);

        Transform.mulToOut(xfa, localPointA, pointA);
        Transform.mulToOut(xfb, localPointB, pointB);

        double separation = pointB.sub(pointA).dot(axis);
        return separation;

      case SeparationType.FACE_A:
        xfa.rotation.transformed(axis, normal);
        Transform.mulToOut(xfa, localPoint, pointA);

        normal.negate();
        xfb.rotation.transposed().transformed(normal, axisB);
        normal.negate();

        localPointB.setFrom(proxyB.vertices[indexB]);
        Transform.mulToOut(xfb, localPointB, pointB);
        double separation = pointB.sub(pointA).dot(normal);
        return separation;

      case SeparationType.FACE_B:
        xfb.rotation.transformed(axis, normal);
        Transform.mulToOut(xfb, localPoint, pointB);

        xfa.rotation.transposed().transformed(normal.negate(), axisA);
        normal.negate();

        localPointA.setFrom(proxyA.vertices[indexA]);
        Transform.mulToOut(xfa, localPointA, pointA);

        double separation = pointA.sub(pointB).dot(normal);
        return separation;

      default:
        assert (false);
        return 0.0;
    }
  }
}

/**
 * Input parameters for TimeOfImpact.
 */
class TimeOfImpactInput {
  final DistanceProxy proxyA = new DistanceProxy();
  final DistanceProxy proxyB = new DistanceProxy();
  final Sweep sweepA = new Sweep();
  final Sweep sweepB = new Sweep();

  /**
   * defines sweep interval [0, tMax]
   */
  double tMax = 0.0;

  TimeOfImpactInput();
}

/** Edouble for TimeOfImpact output. */
class TimeOfImpactOutputState {
  static const int UNKNOWN = 0;
  static const int FAILED = 1;
  static const int OVERLAPPED = 2;
  static const int TOUCHING = 3;
  static const int SEPARATED = 4;
}

/**
 * Output parameters for TimeOfImpact
 */
class TimeOfImpactOutput {
  int state = TimeOfImpactOutputState.UNKNOWN;
  double t = 0.0;

  TimeOfImpactOutput();
}

class SeparationType {
  static const int POINTS = 0;
  static const int FACE_A = 1;
  static const int FACE_B = 2;
}

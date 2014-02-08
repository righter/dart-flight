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
 * Convex Polygon Shape. Create using Body.createShape(ShapeDef) rather than the
 * constructor here, which is off-limits to the likes of you.
 */

part of box2d;

class PolygonShape extends Shape {
  /**
   * Local position of the shape centroid in parent body frame.
   */
  final Vector2 centroid;

  /**
   * The vertices of the shape. Note: Use getVertexCount() rather than
   * vertices.length to get the number of active vertices.
   */
  final List<Vector2> vertices;

  /**
   * The normals of the shape. Note: Use getVertexCount() rather than
   * normals.length to get the number of active normals.
   */
  final List<Vector2> normals;


  int vertexCount = 0;

  /**
   * Constructs a new PolygonShape.
   */
  PolygonShape() :
    super(ShapeType.POLYGON, Settings.POLYGON_RADIUS),
    centroid = new Vector2.zero(),
    vertices = new List<Vector2>.generate(
        Settings.MAX_POLYGON_VERTICES,
        (_) => new Vector2.zero(),
        growable: false
      ),
    normals = new List<Vector2>.generate(
        Settings.MAX_POLYGON_VERTICES,
        (_) => new Vector2.zero(),
        growable: false
      );

  /**
   * Constructs a new PolygonShape equal to the given shape.
   */
  PolygonShape.copy(PolygonShape other) :
      super(ShapeType.POLYGON, other.radius),
      vertexCount = other.vertexCount,
      vertices = new List<Vector2>(Settings.MAX_POLYGON_VERTICES),
      normals = new List<Vector2>(Settings.MAX_POLYGON_VERTICES),
      centroid = new Vector2.copy(other.centroid) {
    // Copy the vertices and normals from the other polygon shape.
    for (int i = 0; i < other.vertices.length; ++i)
      vertices[i] = new Vector2.copy(other.vertices[i]);

    for (int i = 0; i < other.normals.length; ++i)
      normals[i] = new Vector2.copy(other.normals[i]);
  }

  /**
   * Get the supporting vertex index in the given direction.
   */
  int getSupport(Vector2 d) {
    int bestIndex = 0;
    num bestValue = vertices[0].dot(d);
    for (int i = 1; i < vertexCount; ++i) {
      num value = vertices[i].dot(d);
      if (value > bestValue) {
        bestIndex = i;
        bestValue = value;
      }
    }
    return bestIndex;
  }

  Shape clone() => new PolygonShape.copy(this);

  /**
   * Get the supporting vertex in the given direction.
   */
  Vector2 getSupportVertex(Vector2 d) => vertices[getSupport(d)];

  /**
   * Copy vertices. This assumes the vertices define a convex polygon.
   * It is assumed that the exterior is the the right of each edge.
   * TODO(dominich): Consider removing [count].
   */
  void setFrom(List<Vector2> otherVertices, int count) {
    assert (2 <= count && count <= Settings.MAX_POLYGON_VERTICES);
    vertexCount = count;

    // Copy vertices.
    for (int i = 0; i < vertexCount; ++i) {
      assert(vertices[i] != null);
      vertices[i].setFrom(otherVertices[i]);
    }

    Vector2 edge = new Vector2.zero();

    // Compute normals. Ensure the edges have non-zero length.
    for (int i = 0; i < vertexCount; ++i) {
      final int i1 = i;
      final int i2 = i + 1 < vertexCount ? i + 1 : 0;
      edge.setFrom(vertices[i2]).sub(vertices[i1]);

      assert (edge.length2 > Settings.EPSILON * Settings.EPSILON);
      edge.scaleOrthogonalInto(-1.0, normals[i]);
      normals[i].normalize();
    }

    // Compute the polygon centroid.
    computeCentroidToOut(vertices, vertexCount, centroid);
  }

  /**
   * Build vertices to represent an axis-aligned box.
   * hx is the half-width of the body and hy is the half height.
   */
  void setAsBox(double hx, double hy) {
    vertexCount = 4;
    vertices[0].setValues(-hx, -hy);
    vertices[1].setValues(hx, -hy);
    vertices[2].setValues(hx, hy);
    vertices[3].setValues(-hx, hy);
    normals[0].setValues(0.0, -1.0);
    normals[1].setValues(1.0, 0.0);
    normals[2].setValues(0.0, 1.0);
    normals[3].setValues(-1.0, 0.0);
    centroid.setZero();
  }

  /**
   * Build vertices to represent an oriented box. hx is the halfwidth, hy the
   * half-height, center is the center of the box in local coordinates and angle
   * is the rotation of the box in local coordinates.
   */
  void setAsBoxWithCenterAndAngle(double hx, double hy, Vector2 center, double angle) {
    vertexCount = 4;
    setAsBox(hx, hy);
    centroid.setFrom(center);

    Transform xf = new Transform();
    xf.position.setFrom(center);
    xf.rotation.setRotation(angle);

    // Transform vertices and normals.
    for (int i = 0; i < vertexCount; ++i) {
      Transform.mulToOut(xf, vertices[i], vertices[i]);
      xf.rotation.transformed(normals[i], normals[i]);
    }
  }

  /**
   * Set this as a single edge.
   */
  void setAsEdge(Vector2 v1, Vector2 v2) {
    vertexCount = 2;
    vertices[0].setFrom(v1);
    vertices[1].setFrom(v2);
    centroid.setFrom(v1).add(v2).scale(0.5);
    normals[0].setFrom(v2).sub(v1);
    normals[0].scaleOrthogonalInto(-1.0, normals[0]);
    normals[0].normalize();
    normals[1].setFrom(normals[0]).negate();
  }

  /**
   * See Shape.testPoint(Transform, Vector).
   */
  bool testPoint(Transform xf, Vector2 p) {
    Vector2 pLocal = new Vector2.zero();

    pLocal.setFrom(p).sub(xf.position);
    xf.rotation.transposed().transformed(pLocal, pLocal);

    Vector2 temp = new Vector2.zero();

    for (int i = 0; i < vertexCount; ++i) {
      temp.setFrom(pLocal).sub(vertices[i]);
      if (normals[i].dot(temp) > 0)
        return false;
    }

    return true;
  }

  bool raycast(RayCastOutput output, RayCastInput input, Transform xf,
      int childIndex) {
    Vector2 p1 = new Vector2.zero();
    Vector2 p2 = new Vector2.zero();

    p1.setFrom(input.p1).sub(xf.position);
    xf.rotation.transposed().transformed(p1, p1);

    p2.setFrom(input.p2).sub(xf.position);
    xf.rotation.transposed().transformed(p2, p2);

    Vector2 d = p2.sub(p1);

    double lower = 0.0;
    double upper = input.maxFraction;

    int index = -1;

    for (int i = 0; i < vertexCount; ++i) {
      Vector2 normal = normals[i];
      Vector2 vertex = vertices[i];

      Vector2 temp = vertex.sub(p1);
      double numerator = normal.dot(temp);
      double denominator = normal.dot(d);

      if (denominator == 0.0) {
        if (numerator < 0.0)
          return false;
      } else {
        if (denominator < 0.0 && numerator < lower * denominator) {
          lower = numerator / denominator;
          index = i;
        } else if (denominator > 0.0 && numerator < upper * denominator) {
          upper = numerator / denominator;
        }
      }

      if (upper < lower)
        return false;
    }

    assert(0.0 <= lower && lower <= input.maxFraction);

    if (index >= 0) {
      output.fraction = lower;
      Vector2 normal = normals[index];
      Vector2 out = output.normal;
      xf.rotation.transformed(normal, out);
      return true;
    }
    return false;
  }

  /**
   * See Shape.computeAxisAlignedBox(AABB, Transform).
   */
  void computeAxisAlignedBox(Aabb2 argAabb, Transform argXf) {
    final Vector2 lower = new Vector2.zero();
    final Vector2 upper = new Vector2.zero();
    final Vector2 v = new Vector2.zero();

    Transform.mulToOut(argXf, vertices[0], lower);
    upper.setFrom(lower);

    for (int i = 1; i < vertexCount; ++i) {
      Transform.mulToOut(argXf, vertices[i], v);
      Vector2.min(lower, v, lower);
      Vector2.max(upper, v, upper);
    }

    argAabb.min.x = lower.x - radius;
    argAabb.min.y = lower.y - radius;
    argAabb.max.x = upper.x + radius;
    argAabb.max.y = upper.y + radius;
  }

  /**
   * Get a vertex by index.
   */
  Vector2 getVertex(int index) => vertices[index];

  /**
   * Compute the centroid and store the value in the given out parameter.
   */
  void computeCentroidToOut(List<Vector2> vs, int count, Vector2 out) {
    assert (count >= 3);

    out.setValues(0.0, 0.0);
    double area = 0.0;

    if (count == 2) {
      out.setFrom(vs[0]).add(vs[1]).scale(.5);
      return;
    }

    // pRef is the reference point for forming triangles.
    // It's location doesn't change the result (except for rounding error).
    final Vector2 pRef = new Vector2.zero();
    pRef.setZero();

    final Vector2 e1 = new Vector2.zero();
    final Vector2 e2 = new Vector2.zero();

    final double inv3 = 1.0 / 3.0;

    for (int i = 0; i < count; ++i) {
      // Triangle vertices.
      final Vector2 p1 = pRef;
      final Vector2 p2 = vs[i];
      final Vector2 p3 = i + 1 < count ? vs[i + 1] : vs[0];

      e1.setFrom(p2).sub(p1);
      e2.setFrom(p3).sub(p1);

      final double D = e1.cross(e2);

      final double triangleArea = 0.5 * D;
      area += triangleArea;

      // Area weighted centroid
      out.add(p1).add(p2).add(p3).scale(triangleArea * inv3);
    }

    // Centroid
    assert (area > Settings.EPSILON);
    out.scale(1.0 / area);
  }

  /**
   * See Shape.computeMass(MassData)
   */
  void computeMass(MassData massData, double density) {
    // Polygon mass, centroid, and inertia.
    // Let rho be the polygon density in mass per unit area.
    // Then:
    // mass = rho * int(dA)
    // centroid.x = (1/mass) * rho * int(x * dA)
    // centroid.y = (1/mass) * rho * int(y * dA)
    // I = rho * int((x*x + y*y) * dA)
    //
    // We can compute these integrals by summing all the integrals
    // for each triangle of the polygon. To evaluate the integral
    // for a single triangle, we make a change of variables to
    // the (u,v) coordinates of the triangle:
    // x = x0 + e1x * u + e2x * v
    // y = y0 + e1y * u + e2y * v
    // where 0 <= u && 0 <= v && u + v <= 1.
    //
    // We integrate u from [0,1-v] and then v from [0,1].
    // We also need to use the Jacobian of the transformation:
    // D = cross(e1, e2)
    //
    // Simplification: triangle centroid = (1/3) * (p1 + p2 + p3)
    //
    // The rest of the derivation is handled by computer algebra.

    assert (vertexCount >= 2);

    // A line segment has zero mass.
    if (vertexCount == 2) {
      // massData.center = 0.5 * (vertices[0] + vertices[1]);
      massData.center.setFrom(vertices[0]).add(vertices[1]).scale(0.5);
      massData.mass = 0.0;
      massData.inertia = 0.0;
      return;
    }

    final Vector2 center = new Vector2.zero();
    center.setZero();
    double area = 0.0;
    double I = 0.0;

    // pRef is the reference point for forming triangles.
    // It's location doesn't change the result (except for rounding error).
    final Vector2 pRef = new Vector2.zero();
    pRef.setZero();

    final double k_inv3 = 1.0 / 3.0;

    final Vector2 e1 = new Vector2.zero();
    final Vector2 e2 = new Vector2.zero();

    for (int i = 0; i < vertexCount; ++i) {
      // Triangle vertices.
      final Vector2 p1 = pRef;
      final Vector2 p2 = vertices[i];
      final Vector2 p3 = i + 1 < vertexCount ? vertices[i + 1] : vertices[0];

      e1.setFrom(p2);
      e1.sub(p1);

      e2.setFrom(p3);
      e2.sub(p1);

      final double D = e1.cross(e2);

      final double triangleArea = 0.5 * D;
      area += triangleArea;

      // Area weighted centroid
      center.x += triangleArea * k_inv3 * (p1.x + p2.x + p3.x);
      center.y += triangleArea * k_inv3 * (p1.y + p2.y + p3.y);

      final double px = p1.x;
      final double py = p1.y;
      final double ex1 = e1.x;
      final double ey1 = e1.y;
      final double ex2 = e2.x;
      final double ey2 = e2.y;

      final double intx2 = k_inv3 * (0.25 * (ex1 * ex1 + ex2 * ex1 + ex2 * ex2) +
          (px * ex1 + px * ex2)) + 0.5 * px * px;
      final double inty2 = k_inv3 * (0.25 * (ey1 * ey1 + ey2 * ey1 + ey2 * ey2) +
          (py * ey1 + py * ey2)) + 0.5 * py * py;

      I += D * (intx2 + inty2);
    }

    // Total mass
    massData.mass = density * area;

    // Center of mass
    assert (area > Settings.EPSILON);
    center.scale(1.0 / area);
    massData.center.setFrom(center);

    // Inertia tensor relative to the local origin.
    massData.inertia = I * density;
  }

  /**
   * Get the centroid and apply the supplied transform.
   */
  Vector2 applyTransformToCentroid(Transform xf) => Transform.mul(xf, centroid);

  /**
   * Get the centroid and apply the supplied transform. Return the result
   * through the return parameter out.
   */
  Vector2 centroidToOut(Transform xf, Vector2 out) {
    Transform.mulToOut(xf, centroid, out);
    return out;
  }
}

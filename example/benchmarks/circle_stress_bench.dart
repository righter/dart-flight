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

part of BenchmarkRunner;

class CircleStressBench extends Benchmark {
  static const String NAME = "Circle Stress";

  /** The joint used to churn the balls around. */
  RevoluteJoint _joint;

  /** The number of columns of balls in the pen. */
  static const int COLUMNS = 8;

  /** This number of balls will be created on each layer. */
  static const int LOAD_SIZE = 20;

  /** Construct a new Circle Stress Demo. */
  CircleStressBench(List<int> solveLoops, List<int> steps) :
    super(solveLoops, steps);

  String get name => NAME;

  /** Creates all bodies. */
  void initialize() {
    resetWorld();

    {
      final bd = new BodyDef();
      final ground = world.createBody(bd);
      bodies.add(ground);

      PolygonShape shape = new PolygonShape();
      shape.setAsEdge(new Vector2(-40.0, 0.0), new Vector2(40.0, 0.0));
      ground.createFixtureFromShape(shape);
    }

    Body leftWall;
    Body rightWall;

    {
      // Ground
      final sd = new PolygonShape();
      sd.setAsBox(50.0, 10.0);
      final bd = new BodyDef();
      bd.type = BodyType.STATIC;
      bd.position = new Vector2(0.0, -10.0);
      final b = world.createBody(bd);
      bodies.add(b);
      final fd = new FixtureDef();
      fd.shape = sd;
      fd.friction = 1.0;
      b.createFixture(fd);

      // Walls
      sd.setAsBox(3.0, 50.0);
      final wallDef = new BodyDef();
      wallDef.position = new Vector2(45.0, 25.0);
      rightWall = world.createBody(wallDef);
      bodies.add(rightWall);
      rightWall.createFixtureFromShape(sd);
      wallDef.position = new Vector2(-45.0, 25.0);
      leftWall = world.createBody(wallDef);
      bodies.add(leftWall);
      leftWall.createFixtureFromShape(sd);

      // Corners
      final cornerDef = new BodyDef();
      sd.setAsBox(20.0, 3.0);
      cornerDef.angle = (-PI / 4.0);
      cornerDef.position = new Vector2(-35.0, 8.0);
      Body myBod = world.createBody(cornerDef);
      bodies.add(myBod);
      myBod.createFixtureFromShape(sd);
      cornerDef.angle = (PI / 4.0);
      cornerDef.position = new Vector2(35.0, 8.0);
      myBod = world.createBody(cornerDef);
      bodies.add(myBod);
      myBod.createFixtureFromShape(sd);

      // top
      sd.setAsBox(50.0, 10.0);
      final topDef = new BodyDef();
      topDef.type = BodyType.STATIC;
      topDef.angle = 0.0;
      topDef.position = new Vector2(0.0, 75.0);
      final topBody = world.createBody(topDef);
      bodies.add(topBody);
      fd.shape = sd;
      fd.friction = 1.0;
      topBody.createFixture(fd);
    }

    {
      final bd = new BodyDef();
      bd.type = BodyType.DYNAMIC;
      int numPieces = 5;
      num radius = 6;
      bd.position = new Vector2(0.0, 10.0);
      final body = world.createBody(bd);
      bodies.add(body);

      for (int i = 0; i < numPieces; i++) {
        final fd = new FixtureDef();
        final cd = new CircleShape();
        cd.radius = 1.2;
        fd.shape = cd;
        fd.density = 25.0;
        fd.friction = .1;
        fd.restitution = .9;
        num xPos = radius * cos(2 * PI * (i / numPieces.toDouble()));
        num yPos = radius * sin(2 * PI * (i / numPieces.toDouble()));
        cd.position.setValues(xPos, yPos);

        body.createFixture(fd);
      }

      body.bullet = false;

      // Create an empty ground body.
      final bodyDef = new BodyDef();
      final groundBody = world.createBody(bodyDef);

      RevoluteJointDef rjd = new RevoluteJointDef();
      rjd.initialize(body, groundBody, body.position);
      rjd.motorSpeed = PI;
      rjd.maxMotorTorque = 1000000.0;
      rjd.enableMotor = true;
      _joint = world.createJoint(rjd);

      {
        for (int j = 0; j < COLUMNS; j++) {
          for (int i = 0; i < LOAD_SIZE; i++) {
            CircleShape circ = new CircleShape();
            BodyDef bod = new BodyDef();
            bod.type = BodyType.DYNAMIC;
            circ.radius = 1.0 + (i % 2 == 0 ? 1.0 : -1.0) * .5 * .75;
            FixtureDef fd2 = new FixtureDef();
            fd2.shape = circ;
            fd2.density = circ.radius * 1.5;
            fd2.friction = 0.5;
            fd2.restitution = 0.7;
            double xPos = -39.0 + 2 * i;
            double yPos = 50.0 + j;
            bod.position = new Vector2(xPos, yPos);
            Body myBody = world.createBody(bod);
            bodies.add(myBody);
            myBody.createFixture(fd2);
          }
        }
      }
    }
  }
}

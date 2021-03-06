class Snake {

  int score = 1;
  int lifeLeft = 50;  //amount of moves the snake can make before it dies
  int lifetime = 0;  //amount of time the snake has been alive
  int xVel, yVel;
  int foodItterate = 0;  //itterator to run through the foodlist (used for replay)
  
  float fitness = 0;
  
  boolean dead = false;
  boolean replay = false;  //if this snake is a replay of best snake
  
  float[] vision;  //snakes vision
  float[] decision;  //snakes decision
  
  int nb_infos = 3;

  PVector head;
  
  ArrayList<PVector> body;  //snakes body
  ArrayList<Food> foodList;  //list of food positions (used to replay the best snake)
  
  Food food;
  NeuralNet brain;

  // int colors = {2};
  
  Snake() {
    this(HIDDEN_LAYERS);
  }

  Snake(int layer) {
    head = new PVector(X_GRID, HEIGHT/2);
    food = new Food();
    body = new ArrayList<PVector>();
    
    if(!humanPlaying) {
      createSnake();

      brain = new NeuralNet(24, HIDDEN_NODES, 4, layer);
      foodList = new ArrayList<Food>();
      foodList.add(food.clone());
    }
  }

  Snake(ArrayList<Food> foods) {  //this constructor passes in a list of food positions so that a replay can replay the best snake
    createSnake();

    replay = true;
    foodList = new ArrayList<Food>(foods.size());
    
    for(Food f: foods) {  //clone all the food positions in the foodlist
      foodList.add(f.clone());
    };

    food = foodList.get(foodItterate);
    foodItterate++;
  }
  
  void createSnake(){
    vision = new float[24];
    decision = new float[4];
    body = new ArrayList<PVector>();
    head = new PVector(X_GRID, HEIGHT/2);
    body.add(new PVector(X_GRID, (HEIGHT/2)+SIZE));  
    body.add(new PVector(X_GRID, (HEIGHT/2)+(2*SIZE)));
    score += 2;
  }

  void show() {  //show the snake
    food.show();
    fill(255);
    stroke(0);
    for(int i = 0; i < body.size(); i++) {
      rect(body.get(i).x,body.get(i).y,SIZE,SIZE);
    }
    if(dead) {
      fill(150); // TODO
    } else {
      fill(255);
    }
    rect(head.x,head.y,SIZE,SIZE);
  }

  void eat() {  //eat food
    int len = body.size()-1;
    score++;
    if(!humanPlaying && !modelLoaded) {
      if(lifeLeft < 500) {
        if(lifeLeft > 400) {
          lifeLeft = 500; 
        } else {
          lifeLeft+=100;
        }
      }
    }
    
    if(len >= 0) {
      body.add(new PVector(body.get(len).x,body.get(len).y));
    } else {
      body.add(new PVector(head.x,head.y)); 
    }

    if(!replay) {
      food = new Food();
      while(bodyCollision(food.pos)) {
        food = new Food();
      }
      if(!humanPlaying) {
        foodList.add(food);
      }
    } else {  //if the snake is a replay, then we dont want to create new random foods, we want to see the positions the best snake had to collect
      food = foodList.get(foodItterate);
      foodItterate++;
    }
  }
  
  void shiftBody() {  //shift the body to follow the head
    float tempx = head.x;
    float tempy = head.y;
    
    head.x += xVel;
    head.y += yVel;
    
    float temp2x;
    float temp2y;

    for(int i = 0; i < body.size(); i++) {
      temp2x = body.get(i).x;
      temp2y = body.get(i).y;
      body.get(i).x = tempx;
      body.get(i).y = tempy;
      tempx = temp2x;
      tempy = temp2y;
    } 
  }

  Snake cloneForReplay() {  //clone a version of the snake that will be used for a replay
    Snake clone = new Snake(foodList);
    clone.brain = brain.clone();
    return clone;
  }

  Snake clone() {  //clone the snake
    Snake clone = new Snake(HIDDEN_LAYERS);
    clone.brain = brain.clone();
    return clone;
  }

  Snake crossover(Snake parent) {  //crossover the snake with another snake
    Snake child = new Snake(HIDDEN_LAYERS);
    child.brain = brain.crossover(parent.brain);
    return child;
  }

  void mutate() {  //mutate the snakes brain
    brain.mutate(mutationRate); 
  }

  void calculateFitness() {  //calculate the fitness of the snake
    if(score < 10) {
      fitness = floor(lifetime * lifetime) * pow(2,score); 
    } else {
      fitness = floor(lifetime * lifetime);
      fitness *= pow(2,10);
      fitness *= (score-9);
    }
  }

  void turn () {
    look();
    think();
    move();
  }

  void look() {  //look in all 8 directions and check for food, body and wall
    PVector[] directions = {
      new PVector(SIZE,SIZE),
      new PVector(SIZE, 0),
      new PVector(SIZE,-SIZE),
      new PVector(0,SIZE),

      new PVector(0,-SIZE),
      new PVector(-SIZE,SIZE),
      new PVector(-SIZE,0),
      new PVector(-SIZE,-SIZE)
    };

    vision = new float[directions.length*nb_infos];

    for(int i = 0; i < directions.length; i++) {
      float[] temp = lookInDirection(directions[i]);

      vision[i*nb_infos] = temp[0];
      vision[i*nb_infos + 1] = temp[1];
      vision[i*nb_infos + 2] = temp[2];
    }
  }

  float[] lookInDirection(PVector direction) {  //look in a direction and check for food, body and wall
    float look[] = new float[nb_infos];
    PVector pos = new PVector(head.x,  head.y);
    
    boolean foodFound = false;
    boolean bodyFound = false;
    
    pos.add(direction);
    float distance = 1;

    while (!wallCollision(pos)) {
      if(!foodFound && foodCollision(pos)) {
        foodFound = true;
        look[0] = 1;
      }
      if(!bodyFound && bodyCollision(pos)) {
        bodyFound = true;
        look[1] = 1;
      }

      if(replay && seeVision) {
        drawVision(pos, foodFound, bodyFound);
      }

      pos.add(direction);
      distance +=1;
    }

    look[2] = 1/distance;
    return look;
  }

  void drawVision(PVector pos, boolean foodFound, boolean bodyFound) {
    stroke(0,255,0);
    point(pos.x,pos.y);

    if(foodFound) {
      drawEllipse(pos,255,255,51);
    }
    if(bodyFound) {
      drawEllipse(pos,102,0,102);
    }
  }

  void drawEllipse(PVector pos, int r, int g, int b) {
    noStroke();
    fill(r, g, b);
    ellipseMode(CENTER);
    ellipse(pos.x,pos.y,5,5); 
  }

  boolean wallCollision(PVector pos) {  //check if a position collides with the wall
    return (pos.x >= WIDTH  - (SIZE)) 
        || (pos.y >= HEIGHT - (SIZE)) 
        || (pos.x <  SIZE + GRID) 
        || (pos.y <  SIZE);
  }

  boolean bodyCollision(PVector pos) {  //check if a position collides with the snakes body
    for(int i = 0; i < body.size(); i++) {
      if(positionsCollide(pos, body.get(i))) {
        return true;
      }
    } 
    return false;
  }

  boolean foodCollision(PVector pos) {  //check if a position collides with the food
    return positionsCollide(pos, food.pos);
  }

  boolean positionsCollide(PVector pos, PVector objectPos) {
    if(pos.x == objectPos.x && pos.y == objectPos.y) {
      return true;
    }
    return false;
  }

  void think() {  //think about what direction to move
    decision = brain.output(vision);
    int maxIndex = 0;
    float max = 0;
    for(int i = 0; i < decision.length; i++) {
      if(decision[i] > max) {
        max = decision[i];
        maxIndex = i;
      }
    }

    switch(maxIndex) {
      case 0:
      moveUp();
      break;
      case 1:
      moveDown();
      break;
      case 2:
      moveLeft();
      break;
      case 3: 
      moveRight();
      break;
    }  
  }

  void move() {  //move the snake
    if(!dead){
      if(!humanPlaying && !modelLoaded) {
        lifetime++;
        lifeLeft--;
      }
      if(foodCollision(head)) {
        eat();
      }
      shiftBody();
      checkDeath();
    }
  }

  void checkDeath(){
    if(wallCollision(head) || bodyCollision(head) || lifeLeft <= 0 && !humanPlaying) {
      dead = true;
    }
  }

  void moveUp() { 
    if(yVel!=SIZE) {
      xVel = 0; yVel = -SIZE;
    }
  }
  void moveDown() { 
    if(yVel!=-SIZE) {
      xVel = 0; yVel = SIZE; 
    }
  }
  void moveLeft() { 
    if(xVel!=SIZE) {
      xVel = -SIZE; yVel = 0; 
    }
  }
  void moveRight() { 
    if(xVel!=-SIZE) {
      xVel = SIZE; yVel = 0;
    }
  }
}

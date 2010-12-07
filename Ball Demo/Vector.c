/*
  Copyright (C) 2008 Alex Diener

  This software is provided 'as-is', without any express or implied
  warranty.  In no event will the authors be held liable for any damages
  arising from the use of this software.

  Permission is granted to anyone to use this software for any purpose,
  including commercial applications, and to alter it and redistribute it
  freely, subject to the following restrictions:

  1. The origin of this software must not be misrepresented; you must not
     claim that you wrote the original software. If you use this software
     in a product, an acknowledgment in the product documentation would be
     appreciated but is not required.
  2. Altered source versions must be plainly marked as such, and must not be
     misrepresented as being the original software.
  3. This notice may not be removed or altered from any source distribution.

  Alex Diener adiener@sacredsoftware.net
*/

#include "Vector.h"

#include <math.h>

Vector Vector_withValues(float x, float y, float z) {
	Vector vector;
	
	vector.x = x;
	vector.y = y;
	vector.z = z;
	return vector;
}

void Vector_normalize(Vector * vector) {
	float magnitude;
	
	magnitude = sqrt((vector->x * vector->x) + (vector->y * vector->y) + (vector->z * vector->z));
	vector->x /= magnitude;
	vector->y /= magnitude;
	vector->z /= magnitude;
}

Vector Vector_normalized(Vector vector) {
	Vector_normalize(&vector);
	return vector;
}

float Vector_magnitude(Vector vector) {
	return sqrt((vector.x * vector.x) + (vector.y * vector.y) + (vector.z * vector.z));
}

float Vector_magnitudeSquared(Vector vector) {
	return ((vector.x * vector.x) + (vector.y * vector.y) + (vector.z * vector.z));
}

Vector Vector_add(Vector vector1, Vector vector2) {
	return Vector_withValues((vector1.x + vector2.x), (vector1.y + vector2.y), (vector1.z + vector2.z));
}

Vector Vector_subtract(Vector vector1, Vector vector2) {
	return Vector_withValues((vector1.x - vector2.x), (vector1.y - vector2.y), (vector1.z - vector2.z));
}

float Vector_dot(Vector vector1, Vector vector2) {
	return ((vector1.x * vector2.x) + (vector1.y * vector2.y) + (vector1.z * vector2.z));
}

Vector Vector_cross(Vector vector1, Vector vector2) {
	Vector result;
	
	result.x = ((vector1.y * vector2.z) - (vector1.z * vector2.y));
	result.y = ((vector1.z * vector2.x) - (vector1.x * vector2.z));
	result.z = ((vector1.x * vector2.y) - (vector1.y * vector2.x));
	return result;
}

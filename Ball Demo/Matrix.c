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

#include "Matrix.h"

#include <math.h>

#include "Quaternion.h"
#include "Vector.h"

#define degreesToRadians(degrees) (((degrees) * M_PI) / 180.0f)
#define radiansToDegrees(radians) (((radians) * 180.0f) / M_PI)

void Matrix_loadIdentity(Matrix * matrix) {
	matrix->m[0] = 1.0;
	matrix->m[1] = 0.0;
	matrix->m[2] = 0.0;
	matrix->m[3] = 0.0;
	matrix->m[4] = 0.0;
	matrix->m[5] = 1.0;
	matrix->m[6] = 0.0;
	matrix->m[7] = 0.0;
	matrix->m[8] = 0.0;
	matrix->m[9] = 0.0;
	matrix->m[10] = 1.0;
	matrix->m[11] = 0.0;
	matrix->m[12] = 0.0;
	matrix->m[13] = 0.0;
	matrix->m[14] = 0.0;
	matrix->m[15] = 1.0;
}

Matrix Matrix_identity() {
	Matrix matrix;
	
	Matrix_loadIdentity(&matrix);
	return matrix;
}

Matrix Matrix_withValues(float m0,  float m4,  float m8,  float m12,
                         float m1,  float m5,  float m9,  float m13,
                         float m2,  float m6,  float m10, float m14,
                         float m3,  float m7,  float m11, float m15) {
	Matrix matrix;
	
	matrix.m[0]  = m0;
	matrix.m[1]  = m1;
	matrix.m[2]  = m2;
	matrix.m[3]  = m3;
	matrix.m[4]  = m4;
	matrix.m[5]  = m5;
	matrix.m[6]  = m6;
	matrix.m[7]  = m7;
	matrix.m[8]  = m8;
	matrix.m[9]  = m9;
	matrix.m[10] = m10;
	matrix.m[11] = m11;
	matrix.m[12] = m12;
	matrix.m[13] = m13;
	matrix.m[14] = m14;
	matrix.m[15] = m15;
	return matrix;
}

Matrix Matrix_fromDirectionVectors(Vector right, Vector up, Vector front) {
	Matrix matrix;
	
	Matrix_loadIdentity(&matrix);
	matrix.m[0]  = right.x;
	matrix.m[1]  = right.y;
	matrix.m[2]  = right.z;
	matrix.m[4]  = up.x;
	matrix.m[5]  = up.y;
	matrix.m[6]  = up.z;
	matrix.m[8]  = front.x;
	matrix.m[9]  = front.y;
	matrix.m[10] = front.z;
	return matrix;
}

void Matrix_multiply(Matrix * matrix1, Matrix m2) {
	Matrix m1, result;
	
	m1 = *matrix1;
	
	result.m[0]  = m1.m[0] * m2.m[0]  + m1.m[4] * m2.m[1]  + m1.m[8]  * m2.m[2]  + m1.m[12] * m2.m[3];
	result.m[1]  = m1.m[1] * m2.m[0]  + m1.m[5] * m2.m[1]  + m1.m[9]  * m2.m[2]  + m1.m[13] * m2.m[3];
	result.m[2]  = m1.m[2] * m2.m[0]  + m1.m[6] * m2.m[1]  + m1.m[10] * m2.m[2]  + m1.m[14] * m2.m[3];
	result.m[3]  = m1.m[3] * m2.m[0]  + m1.m[7] * m2.m[1]  + m1.m[11] * m2.m[2]  + m1.m[15] * m2.m[3];
	result.m[4]  = m1.m[0] * m2.m[4]  + m1.m[4] * m2.m[5]  + m1.m[8]  * m2.m[6]  + m1.m[12] * m2.m[7];
	result.m[5]  = m1.m[1] * m2.m[4]  + m1.m[5] * m2.m[5]  + m1.m[9]  * m2.m[6]  + m1.m[13] * m2.m[7];
	result.m[6]  = m1.m[2] * m2.m[4]  + m1.m[6] * m2.m[5]  + m1.m[10] * m2.m[6]  + m1.m[14] * m2.m[7];
	result.m[7]  = m1.m[3] * m2.m[4]  + m1.m[7] * m2.m[5]  + m1.m[11] * m2.m[6]  + m1.m[15] * m2.m[7];
	result.m[8]  = m1.m[0] * m2.m[8]  + m1.m[4] * m2.m[9]  + m1.m[8]  * m2.m[10] + m1.m[12] * m2.m[11];
	result.m[9]  = m1.m[1] * m2.m[8]  + m1.m[5] * m2.m[9]  + m1.m[9]  * m2.m[10] + m1.m[13] * m2.m[11];
	result.m[10] = m1.m[2] * m2.m[8]  + m1.m[6] * m2.m[9]  + m1.m[10] * m2.m[10] + m1.m[14] * m2.m[11];
	result.m[11] = m1.m[3] * m2.m[8]  + m1.m[7] * m2.m[9]  + m1.m[11] * m2.m[10] + m1.m[15] * m2.m[11];
	result.m[12] = m1.m[0] * m2.m[12] + m1.m[4] * m2.m[13] + m1.m[8]  * m2.m[14] + m1.m[12] * m2.m[15];
	result.m[13] = m1.m[1] * m2.m[12] + m1.m[5] * m2.m[13] + m1.m[9]  * m2.m[14] + m1.m[13] * m2.m[15];
	result.m[14] = m1.m[2] * m2.m[12] + m1.m[6] * m2.m[13] + m1.m[10] * m2.m[14] + m1.m[14] * m2.m[15];
	result.m[15] = m1.m[3] * m2.m[12] + m1.m[7] * m2.m[13] + m1.m[11] * m2.m[14] + m1.m[15] * m2.m[15];
	
	*matrix1 = result;
}

Matrix Matrix_multiplied(Matrix matrix1, Matrix matrix2) {
	Matrix_multiply(&matrix1, matrix2);
	return matrix1;
}

void Matrix_translate(Matrix * matrix, float x, float y, float z) {
	Matrix translationMatrix;
	
	Matrix_loadIdentity(&translationMatrix);
	translationMatrix.m[12] = x;
	translationMatrix.m[13] = y;
	translationMatrix.m[14] = z;
	Matrix_multiply(matrix, translationMatrix);
}

Matrix Matrix_translated(Matrix matrix, float x, float y, float z) {
	Matrix_translate(&matrix, x, y, z);
	return matrix;
}

void Matrix_scale(Matrix * matrix, float x, float y, float z) {
	Matrix scalingMatrix;
	
	Matrix_loadIdentity(&scalingMatrix);
	scalingMatrix.m[0] = x;
	scalingMatrix.m[5] = y;
	scalingMatrix.m[10] = z;
	Matrix_multiply(matrix, scalingMatrix);
}

Matrix Matrix_scaled(Matrix matrix, float x, float y, float z) {
	Matrix_scale(&matrix, x, y, z);
	return matrix;
}

void Matrix_rotate(Matrix * matrix, Vector axis, float angle) {
	Matrix rotationMatrix;
	Quaternion quaternion;
	
	quaternion = Quaternion_fromAxisAngle(axis, angle);
	rotationMatrix = Quaternion_toMatrix(quaternion);
	Matrix_multiply(matrix, rotationMatrix);
}

Matrix Matrix_rotated(Matrix matrix, Vector axis, float angle) {
	Matrix_rotate(&matrix, axis, angle);
	return matrix;
}

void Matrix_shearX(Matrix * matrix, float y, float z) {
	Matrix shearingMatrix;
	
	Matrix_loadIdentity(&shearingMatrix);
	shearingMatrix.m[1] = y;
	shearingMatrix.m[2] = z;
	Matrix_multiply(matrix, shearingMatrix);
}

Matrix Matrix_shearedX(Matrix matrix, float y, float z) {
	Matrix_shearX(&matrix, y, z);
	return matrix;
}

void Matrix_shearY(Matrix * matrix, float x, float z) {
	Matrix shearingMatrix;
	
	Matrix_loadIdentity(&shearingMatrix);
	shearingMatrix.m[4] = x;
	shearingMatrix.m[6] = z;
	Matrix_multiply(matrix, shearingMatrix);
}

Matrix Matrix_shearedY(Matrix matrix, float x, float z) {
	Matrix_shearY(&matrix, x, z);
	return matrix;
}

void Matrix_shearZ(Matrix * matrix, float x, float y) {
	Matrix shearingMatrix;
	
	Matrix_loadIdentity(&shearingMatrix);
	shearingMatrix.m[8] = x;
	shearingMatrix.m[9] = y;
	Matrix_multiply(matrix, shearingMatrix);
}

Matrix Matrix_shearedZ(Matrix matrix, float x, float y) {
	Matrix_shearZ(&matrix, x, y);
	return matrix;
}

void Matrix_applyPerspective(Matrix * matrix, float fovY, float aspect, float zNear, float zFar) {
	Matrix perspectiveMatrix;
	float sine, cotangent, deltaZ;
	
	fovY = (degreesToRadians(fovY) / 2.0f);
	deltaZ = (zFar - zNear);
	sine = sin(fovY);
	if (deltaZ == 0.0f || sine == 0.0f || aspect == 0.0f) {
		return;
	}
	cotangent = (cos(fovY) / sine);
	
	Matrix_loadIdentity(&perspectiveMatrix);
	perspectiveMatrix.m[0] = (cotangent / aspect);
	perspectiveMatrix.m[5] = cotangent;
	perspectiveMatrix.m[10] = (-(zFar + zNear) / deltaZ);
	perspectiveMatrix.m[11] = -1.0f;
	perspectiveMatrix.m[14] = ((-2.0f * zNear * zFar) / deltaZ);
	perspectiveMatrix.m[15] = 0.0f;
	Matrix_multiply(matrix, perspectiveMatrix);
}

Matrix Matrix_perspective(Matrix matrix, float fovY, float aspect, float zNear, float zFar) {
	Matrix_applyPerspective(&matrix, fovY, aspect, zNear, zFar);
	return matrix;
}

void Matrix_transpose(Matrix * matrix) {
	*matrix = Matrix_withValues(matrix->m[0],  matrix->m[1],  matrix->m[2],  matrix->m[3],
	                            matrix->m[4],  matrix->m[5],  matrix->m[6],  matrix->m[7],
	                            matrix->m[8],  matrix->m[9],  matrix->m[10], matrix->m[11],
	                            matrix->m[12], matrix->m[13], matrix->m[14], matrix->m[15]);
}

Matrix Matrix_transposed(Matrix matrix) {
	Matrix_transpose(&matrix);
	return matrix;
}

static float Matrix_subdeterminant(Matrix matrix, int excludeIndex) {
	int index4x4, index3x3;
	float matrix3x3[9];
	
	index3x3 = 0;
	for (index4x4 = 0; index4x4 < 16; index4x4++) {
		if (index4x4 / 4 == excludeIndex / 4 ||
		    index4x4 % 4 == excludeIndex % 4) {
			continue;
		}
		matrix3x3[index3x3++] = matrix.m[index4x4];
	}
	
	return matrix3x3[0] * (matrix3x3[4] * matrix3x3[8] - matrix3x3[5] * matrix3x3[7]) -
	       matrix3x3[3] * (matrix3x3[1] * matrix3x3[8] - matrix3x3[2] * matrix3x3[7]) +
	       matrix3x3[6] * (matrix3x3[1] * matrix3x3[5] - matrix3x3[2] * matrix3x3[4]);
}

float Matrix_determinant(Matrix matrix) {
	float subdeterminant0, subdeterminant1, subdeterminant2, subdeterminant3;
	
	subdeterminant0 = Matrix_subdeterminant(matrix, 0);
	subdeterminant1 = Matrix_subdeterminant(matrix, 4);
	subdeterminant2 = Matrix_subdeterminant(matrix, 8);
	subdeterminant3 = Matrix_subdeterminant(matrix, 12);
	
	return matrix.m[0]  *  subdeterminant0 +
	       matrix.m[4]  * -subdeterminant1 +
	       matrix.m[8]  *  subdeterminant2 +
	       matrix.m[12] * -subdeterminant3;
}

void Matrix_invert(Matrix * matrix) {
	float determinant;
	Matrix result;
	int index, indexTransposed;
	int sign;
	
	determinant = Matrix_determinant(*matrix);
	for (index = 0; index < 16; index++) {
		sign = 1 - (((index % 4) + (index / 4)) % 2) * 2;
		indexTransposed = (index % 4) * 4 + index / 4;
		result.m[indexTransposed] = Matrix_subdeterminant(*matrix, index) * sign / determinant;
	}
	
	*matrix = result;
}

Matrix Matrix_inverted(Matrix matrix) {
	Matrix_invert(&matrix);
	return matrix;
}

Vector Matrix_multiplyVector(Matrix matrix, Vector vector) {
	Vector result;
	
	result.x = ((matrix.m[0] * vector.x) + (matrix.m[4] * vector.y) + (matrix.m[8]  * vector.z) + matrix.m[12]);
	result.y = ((matrix.m[1] * vector.x) + (matrix.m[5] * vector.y) + (matrix.m[9]  * vector.z) + matrix.m[13]);
	result.z = ((matrix.m[2] * vector.x) + (matrix.m[6] * vector.y) + (matrix.m[10] * vector.z) + matrix.m[14]);
	return result;
}

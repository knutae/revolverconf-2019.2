#if defined(DEBUG)
#define API_CHECK 1
#endif

#include <GLES3/gl32.h>
#include <gtk/gtk.h>
#include "gen/shaders.h"

#define EMPTY_SHADER "void main(){}"

#define GEOMETRY_SHADER \
  "#version 450\n" \
  "layout(points)in;" \
  "layout(triangle_strip,max_vertices=4)out;" \
  "out vec2 C;" \
  "void E(float u,float v){C=vec2(u+1,v+1);gl_Position=vec4(u,v,0,1);EmitVertex();}" \
  "void main(){E(-1,-1);E(1,-1);E(-1,1);E(1,1);}"

#if defined(API_CHECK)
void handle_compile_error(GLuint shader) {
  GLint success = 0;
  glGetShaderiv(shader, GL_COMPILE_STATUS, &success);
  if (!success) {
    char logBuffer[4096];
    GLsizei length;
    glGetShaderInfoLog(shader, sizeof(logBuffer), &length, logBuffer);
    printf("Shader compile error.\n%s\n", logBuffer);
    exit(1);
  }
}

void handle_link_error(GLuint program) {
  GLint success = 0;
  glGetProgramiv(program, GL_LINK_STATUS, &success);
  if (!success) {
    char logBuffer[4096];
    GLsizei length;
    glGetShaderInfoLog(program, sizeof(logBuffer), &length, logBuffer);
    printf("Shader link error.\n%s\n", logBuffer);
    exit(1);
  }
}
#else
#define handle_compile_error(shader) do {} while(0)
#define handle_link_error(program) do {} while(0)
#endif

GLuint create_shader(const char *source, GLenum type) {
  GLuint shader = glCreateShader(type);
  glShaderSource(shader, 1, &source, NULL);
  glCompileShader(shader);
  handle_compile_error(shader);
  return shader;
}

GLuint vba;
GLuint program;
GLuint fragment_shader;

gboolean render(GtkGLArea *area, GdkGLContext *context) {
  GtkAllocation size;
  gtk_widget_get_allocation(GTK_WIDGET(area), &size);
  glUseProgram(program);
  glBindVertexArray(vba);
  glUniform1f(0, size.width);
  glUniform1f(1, size.height);
  glDrawArrays(GL_POINTS, 0, 1);
  return TRUE;
}

void realize(GtkGLArea *area) {
  gtk_gl_area_make_current(area);
#ifdef API_CHECK
  if (gtk_gl_area_get_error (area) != NULL) {
    printf("gtk_gl_area_get_error");
    exit(1);
  }
#endif

  program = glCreateProgram();
  GLuint vertex_shader = create_shader(EMPTY_SHADER, GL_VERTEX_SHADER);
  GLuint geometry_shader = create_shader(GEOMETRY_SHADER, GL_GEOMETRY_SHADER);
  fragment_shader = create_shader(fshader_glsl, GL_FRAGMENT_SHADER);
  glAttachShader(program, vertex_shader);
  glAttachShader(program, geometry_shader);
  glAttachShader(program, fragment_shader);
  glLinkProgram(program);
  handle_link_error(program);
  glGenVertexArrays(1, &vba);
}

void key_press(GtkWidget * widget, GdkEventKey * event, GtkGLArea * area) {
  if (event->keyval == GDK_KEY_Escape) {
    gtk_main_quit();
  }
}

int main() {
  gtk_init(NULL, NULL);
  GtkWidget * window = gtk_window_new(GTK_WINDOW_TOPLEVEL);
  GtkWidget * area = gtk_gl_area_new();
  gtk_gl_area_set_auto_render(GTK_GL_AREA(area), FALSE);

  gtk_container_add(GTK_CONTAINER(window), area);
  gtk_window_fullscreen(GTK_WINDOW(window));

  g_signal_connect (area, "realize", G_CALLBACK (realize), NULL);
  g_signal_connect (area, "render", G_CALLBACK (render), NULL);
  g_signal_connect (window, "key-press-event", G_CALLBACK(key_press), area);

  gtk_widget_show_all(window);

  gtk_main();
  return 0;
}

#ifndef DEBUG
void _start() {
    asm("call main");
}
#endif
